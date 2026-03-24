unit module W::Slots;

my sub from-json(Str $s) { Rakudo::Internals::JSON.from-json($s) }
my sub to-json($obj)      { Rakudo::Internals::JSON.to-json($obj) }

# Derive a filesystem-safe project-id from the repo root path
sub project-id(IO::Path $repo-root --> Str) is export {
    $repo-root.resolve.Str.subst('/', '_', :g).subst(/^_/, '');
}

# Return the state directory for a project, creating it if needed
sub state-dir(IO::Path $repo-root --> IO::Path) is export {
    my $dir = %*ENV<HOME>.IO.add('.local/state/w/projects').add(project-id($repo-root));
    $dir.mkdir unless $dir.d;
    $dir;
}

# Path to slots.json for a project
sub slots-file(IO::Path $repo-root --> IO::Path) {
    state-dir($repo-root).add('slots.json');
}

# Read current slot assignments from disk
sub read-slots(IO::Path $repo-root --> Hash) {
    my $file = slots-file($repo-root);
    return {} unless $file.e;
    my $content = $file.slurp.trim;
    return {} unless $content;
    from-json($content);
}

# Write slot assignments to disk
sub write-slots(IO::Path $repo-root, %slots) {
    slots-file($repo-root).spurt(to-json(%slots) ~ "\n");
}

# Find the lowest available slot (0 is reserved for main)
sub lowest-available-slot(%slots --> Int) {
    my @used = %slots.values.map(*.Int);
    my $slot = 1;
    $slot++ while $slot ∈ @used;
    $slot;
}

# Assign a slot to a worktree name; returns the slot number
sub assign-slot(Str :$name, IO::Path :$repo-root --> Int) is export {
    my %slots = read-slots($repo-root);
    # Already assigned? Return existing slot
    return %slots{$name}.Int if %slots{$name}:exists;
    my $slot = lowest-available-slot(%slots);
    %slots{$name} = $slot;
    write-slots($repo-root, %slots);
    $slot;
}

# Free a slot for a worktree name
sub free-slot(Str :$name, IO::Path :$repo-root) is export {
    my %slots = read-slots($repo-root);
    %slots{$name}:delete;
    write-slots($repo-root, %slots);
}

# Get the slot for a worktree name (returns Int or Nil)
sub get-slot(Str :$name, IO::Path :$repo-root --> Int) is export {
    my %slots = read-slots($repo-root);
    return 0 if $name eq 'main';
    %slots{$name}:exists ?? %slots{$name}.Int !! Int;
}
