unit module W::Display;

# ANSI color codes
my constant RESET  = "\e[0m";
my constant BOLD   = "\e[1m";
my constant RED    = "\e[31m";
my constant GREEN  = "\e[32m";
my constant YELLOW = "\e[33m";
my constant BLUE   = "\e[34m";
my constant CYAN   = "\e[36m";
my constant DIM    = "\e[2m";

# Detect whether to use color (check if stdout is a TTY)
sub use-color(--> Bool) is export {
    ?$*OUT.t && !(%*ENV<NO_COLOR>:exists);
}

# Color formatting helpers
sub color(Str $text, *@codes --> Str) is export {
    return $text unless use-color();
    @codes.join ~ $text ~ RESET;
}

sub bold(Str $text --> Str) is export  { color($text, BOLD) }
sub dim(Str $text --> Str) is export   { color($text, DIM) }
sub red(Str $text --> Str) is export   { color($text, RED) }
sub green(Str $text --> Str) is export { color($text, GREEN) }
sub yellow(Str $text --> Str) is export { color($text, YELLOW) }
sub blue(Str $text --> Str) is export  { color($text, BLUE) }
sub cyan(Str $text --> Str) is export  { color($text, CYAN) }

sub bold-green(Str $text --> Str) is export { color($text, BOLD, GREEN) }
sub bold-cyan(Str $text --> Str) is export  { color($text, BOLD, CYAN) }
sub bold-yellow(Str $text --> Str) is export { color($text, BOLD, YELLOW) }

# Format dirty/clean status with color and file count
sub format-status(Bool $dirty, Int $count --> Str) is export {
    if $dirty {
        yellow("dirty") ~ "  " ~ dim("$count file{$count == 1 ?? '' !! 's'} changed");
    } else {
        green("clean");
    }
}

# Format ahead/behind with color
sub format-ahead-behind(Str $ab --> Str) is export {
    return '' unless $ab;
    cyan($ab);
}

# Format server status line (for w ls)
sub format-server-status(Str $status --> Str) is export {
    return '' unless $status;
    green("●") ~ " " ~ $status.subst(/^'● '/, '');
}
