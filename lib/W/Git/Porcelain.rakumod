unit module W::Git::Porcelain;

grammar WorktreeList is export {
    token TOP        { <entry> [ \n \n <entry> ]* \n? }
    token entry      { <wt-path> \n <wt-head> [ \n <wt-branch> ]? [ \n <wt-detached> ]? [ \n <wt-bare> ]? }
    token wt-path      { 'worktree ' $<path>=(\N+) }
    token wt-head      { 'HEAD ' $<sha>=(<xdigit>+) }
    token wt-branch    { 'branch ' $<ref>=(\N+) }
    token wt-detached  { 'detached' }
    token wt-bare      { 'bare' }
}

class WorktreeListActions is export {
    method TOP($/) {
        make $<entry>.map(*.made).list;
    }
    method entry($/) {
        my %h = path => $<wt-path><path>.Str, sha => $<wt-head><sha>.Str;
        %h<branch> = $<wt-branch><ref>.Str.subst(/^ 'refs/heads/' /, '') if $<wt-branch>;
        %h<detached> = True if $<wt-detached>;
        %h<bare> = True if $<wt-bare>;
        make %h;
    }
}

sub parse-worktree-list(Str $output --> List) is export {
    my $match = WorktreeList.parse($output.trim, actions => WorktreeListActions.new);
    die "Failed to parse git worktree list output" unless $match;
    $match.made;
}
