unit module W::Project;

sub find-repo-root(--> IO::Path) is export {
    my $proc = run 'git', 'rev-parse', '--show-toplevel', :out, :err;
    die "Not inside a git repository" unless $proc.exitcode == 0;
    $proc.out.slurp(:close).trim.IO;
}

sub project-name(IO::Path $root --> Str) is export {
    $root.basename;
}

sub parent-dir(IO::Path $root --> IO::Path) is export {
    $root.parent;
}

sub find-main-worktree(--> IO::Path) is export {
    my $proc = run 'git', 'worktree', 'list', :out, :err;
    die "Not inside a git repository" unless $proc.exitcode == 0;
    my $first-line = $proc.out.slurp(:close).lines[0];
    $first-line.words[0].IO;
}
