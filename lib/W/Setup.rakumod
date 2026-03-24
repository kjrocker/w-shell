unit module W::Setup;

sub run-setup(IO::Path :$worktree-path, :@commands --> List) is export {
    my @results;
    for @commands -> $cmd {
        note "Running setup: $cmd";
        my $proc = shell $cmd, :cwd($worktree-path.Str), :out(Nil), :err;
        my $err = $proc.err.slurp(:close);
        if $proc.exitcode != 0 {
            note "Warning: setup command '$cmd' failed: $err";
        }
        @results.push($proc.exitcode);
    }
    @results.List;
}
