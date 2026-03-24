unit module W::Raku;

our sub run(@args) is export {
    if @args.elems == 0 || @args[0] eq '--help' {
        say "Usage: w-raku <command>";
        say "";
        say "Commands:";
        say "  --help    Show this help message";
        say "  --version Show version";
        exit 0;
    }

    if @args[0] eq '--version' {
        say "w-raku 0.0.1";
        exit 0;
    }

    note "Unknown command: @args[0]";
    exit 1;
}
