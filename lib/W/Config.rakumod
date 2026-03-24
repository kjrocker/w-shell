unit module W::Config;

use TOML::Thumb;

sub load-config(IO::Path $repo-root --> Hash) is export {
    my $config-file = $repo-root.add('.wtconfig.toml');
    return {} unless $config-file.e;
    from-toml($config-file.slurp);
}
