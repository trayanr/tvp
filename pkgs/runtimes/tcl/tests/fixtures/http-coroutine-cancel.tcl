# Deterministic cancellation/reuse checks; no sockets or timing assumptions.
package require http 2.10
set ::callbackErrors {}
set ::resumes 0
proc bgerror {message} {lappend ::callbackErrors $message}
proc drainCallbacks {} {update}
proc suspended {variable {timeout {}}} {
    ::http::cwaiter::cwait $variable {} $timeout timeout-result
    incr ::resumes
}
proc replacement {} {
    yield
    error wrong-generation-resumed
}
proc requireNoTrace {variable} {
    if {[trace info variable $variable] ne {}} {error abandoned-write-trace}
}
foreach ordering {before-write after-write} {
    set token ::http::tvp-cancel-$ordering
    set name ${token}--SocketCoroutine
    set variable ::tvp-result-$ordering
    coroutine $name suspended $variable 60000
    if {$ordering eq "after-write"} {set $variable ready}
    ::http::cleanup $token
    requireNoTrace $variable
    if {[after info] ne {}} {error abandoned-timer}
    coroutine $name replacement
    if {$ordering eq "before-write"} {set $variable ready}
    drainCallbacks
    if {$::callbackErrors ne {} || $::resumes != 0 || [info commands $name] eq {}} {
        error "cancelled wait resumed a replacement: $::callbackErrors"
    }
    rename $name {}
}
coroutine ::tvp-live suspended ::tvp-live-result
set ::tvp-live-result ready
drainCallbacks
if {$::resumes != 1 || [info commands ::tvp-live] ne {} || $::callbackErrors ne {}} {
    error live-resume
}
requireNoTrace ::tvp-live-result
proc failing {} {
    ::http::cwaiter::cwait ::tvp-error-result
    error live-coroutine-error
}
coroutine ::tvp-error failing
set ::tvp-error-result ready
drainCallbacks
if {$::callbackErrors ne {live-coroutine-error}} {error "live error hidden: $::callbackErrors"}
requireNoTrace ::tvp-error-result
puts http-coroutine-cancel-ok
