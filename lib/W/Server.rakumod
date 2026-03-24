unit module W::Server;

use W::Slots;

my sub from-json(Str $s) { Rakudo::Internals::JSON.from-json($s) }
my sub to-json($obj)      { Rakudo::Internals::JSON.to-json($obj) }

# Path to ports.json for a project
sub ports-file(IO::Path $repo-root --> IO::Path) is export {
    state-dir($repo-root).add('ports.json');
}

# Read current ports state from disk
sub read-ports(IO::Path $repo-root --> Hash) is export {
    my $file = ports-file($repo-root);
    return {} unless $file.e;
    my $content = $file.slurp.trim;
    return {} unless $content;
    from-json($content);
}

# Write ports state to disk
sub write-ports(IO::Path $repo-root, %ports) is export {
    ports-file($repo-root).spurt(to-json(%ports) ~ "\n");
}

# Start servers for a worktree based on config
# Returns list of hashes with server info (name, port, pid)
sub start-servers(Str :$name, IO::Path :$repo-root, :%config,
                  Str :$only --> List) is export {
    my @server-configs = (%config<server> // []).list;
    return ().list unless @server-configs;

    my $slot = get-slot(:$name, :$repo-root) // 0;
    my %ports = read-ports($repo-root);
    my %entry = %ports{$name} // {};
    %entry<slot> = $slot;
    %entry<servers> //= {};

    my @started;

    for @server-configs -> $srv {
        my $srv-name = $srv<name>;
        next if $only && $srv-name ne $only;

        my $port = $srv<base-port> + $slot;
        my $command = $srv<command>;
        my $port-env = $srv<port-env>;

        note "Starting $srv-name ($command) on :$port...";

        my $proc = Proc::Async.new('sh', '-c', $command);
        my %env = %*ENV;
        %env{$port-env} = $port.Str;

        my $handle = $proc.start(:%env, :out('/dev/null'), :err('/dev/null'));
        # pid is a Promise; await it to get the actual Int
        my $pid = await $proc.pid;

        %entry<servers>{$srv-name} = { port => $port, pid => $pid };
        @started.push({ name => $srv-name, port => $port, pid => $pid });
    }

    %ports{$name} = %entry;
    write-ports($repo-root, %ports);

    @started.list;
}

# Stop servers for a worktree
sub stop-servers(Str :$name, IO::Path :$repo-root, Str :$only --> List) is export {
    my %ports = read-ports($repo-root);
    return ().list unless %ports{$name}:exists;

    my %entry = %ports{$name};
    my %servers = %entry<servers> // {};
    my @stopped;

    for %servers.kv -> $srv-name, $info {
        next if $only && $srv-name ne $only;

        my $pid = $info<pid>;
        if $pid && pid-alive($pid) {
            note "Stopping $srv-name (pid $pid)...";
            try shell "kill $pid 2>/dev/null";
            # Wait briefly then force kill if still alive
            sleep 0.2;
            if pid-alive($pid) {
                try shell "kill -9 $pid 2>/dev/null";
            }
        }
        @stopped.push($srv-name);
    }

    # Update ports.json
    if $only {
        %entry<servers>{$only}:delete;
        if %entry<servers>.elems == 0 {
            %ports{$name}:delete;
        } else {
            %ports{$name} = %entry;
        }
    } else {
        %ports{$name}:delete;
    }
    write-ports($repo-root, %ports);

    @stopped.list;
}

# Check if a PID is alive
sub pid-alive(Int() $pid --> Bool) is export {
    "/proc/$pid".IO.d;
}
