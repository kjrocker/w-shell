unit module W::Worktree;

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
