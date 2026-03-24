unit module W::Nav;

sub cd-target-dir(--> IO::Path) is export {
    %*ENV<HOME>.IO.add('.local/state/w');
}

sub write-cd-target(IO::Path $path) is export {
    my $dir = cd-target-dir();
    unless $dir.d {
        my @parts;
        my $cur = $dir;
        while !$cur.d && $cur.Str ne '/' {
            @parts.unshift($cur);
            $cur = $cur.parent;
        }
        .mkdir for @parts;
    }
    $dir.add('cd-target').spurt($path.Str);
}
