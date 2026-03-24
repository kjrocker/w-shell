unit module W::Worktree;

use W::Git::Porcelain;

sub resolve-path-template(Str :$template, Str :$project, Str :$name,
                           IO::Path :$parent, IO::Path :$home --> IO::Path) is export {
    die "Path template must contain \{name}" unless $template.contains('{name}');
    $template
        .subst('{project}', $project, :g)
        .subst('{name}',    $name,    :g)
        .subst('{parent}',  $parent.Str, :g)
        .subst('{home}',    $home.Str, :g)
        .IO;
}

sub resolve-worktree-path(IO::Path :$parent, Str :$project, Str :$name,
                           Str :$template, IO::Path :$home --> IO::Path) is export {
    if $template {
        resolve-path-template(:$template, :$project, :$name, :$parent,
                              home => $home // $*HOME);
    } else {
        $parent.add("{$project}.{$name}");
    }
}

sub worktree-exists(IO::Path :$path --> Bool) is export {
    $path.d && $path.add('.git').e;
}

sub create-worktree(Str :$name, IO::Path :$path, IO::Path :$repo-root) is export {
    $path.parent.mkdir unless $path.parent.d;

    my $proc = run 'git', '-C', $repo-root.Str, 'worktree', 'add',
                    '-b', $name, $path.Str, 'main', :err;
    my $err = $proc.err.slurp(:close);

    # If branch already exists, retry without -b
    if $proc.exitcode != 0 && $err.contains("already exists") {
        my $retry = run 'git', '-C', $repo-root.Str, 'worktree', 'add',
                        $path.Str, $name, :err;
        my $retry-err = $retry.err.slurp(:close);
        die "Failed to create worktree: $retry-err" unless $retry.exitcode == 0;
    } elsif $proc.exitcode != 0 {
        die "Failed to create worktree: $err";
    }
}

sub list-worktrees(IO::Path :$repo-root --> List) is export {
    my $proc = run 'git', '-C', $repo-root.Str, 'worktree', 'list', '--porcelain', :out, :err;
    die "Failed to list worktrees" unless $proc.exitcode == 0;
    my $output = $proc.out.slurp(:close);
    return ().list unless $output.trim;
    parse-worktree-list($output);
}

sub worktree-dirty(IO::Path :$path --> Bool) is export {
    my $proc = run 'git', '-C', $path.Str, 'status', '--porcelain', :out, :err;
    return False unless $proc.exitcode == 0;
    $proc.out.slurp(:close).trim.chars > 0;
}

sub worktree-ahead-behind(IO::Path :$path --> Str) is export {
    my $proc = run 'git', '-C', $path.Str, 'rev-list', '--left-right', '--count', 'HEAD...@{upstream}',
                    :out, :err;
    return '' unless $proc.exitcode == 0;
    my $out = $proc.out.slurp(:close).trim;
    my ($ahead, $behind) = $out.split(/\s+/).map(*.Int);
    my @parts;
    @parts.push("ahead $ahead") if $ahead;
    @parts.push("behind $behind") if $behind;
    @parts ?? "[{@parts.join(', ')}]" !! '';
}

sub remove-worktree(Str :$name, IO::Path :$repo-root, Bool :$force = False) is export {
    # Check for unmerged commits unless forcing
    unless $force {
        my $proc = run 'git', '-C', $repo-root.Str, 'log', '--oneline', "main..$name",
                        :out, :err;
        if $proc.exitcode == 0 {
            my $unmerged = $proc.out.slurp(:close).trim;
            if $unmerged.chars > 0 {
                die "Branch $name has unmerged commits (use --force to override)";
            }
        }
    }

    # Find the worktree path by matching branch name
    my @wts = list-worktrees(:$repo-root);
    my $wt = @wts.first({ (.<branch> // '') eq $name });
    die "Worktree for branch '$name' not found" unless $wt;

    my @args = 'git', '-C', $repo-root.Str, 'worktree', 'remove';
    @args.push('--force') if $force;
    @args.push($wt<path>);

    my $proc = run |@args, :err;
    my $err = $proc.err.slurp(:close);
    die "Failed to remove worktree: $err" unless $proc.exitcode == 0;
}
