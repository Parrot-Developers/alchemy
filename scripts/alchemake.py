#!/usr/bin/env python3
#
# This script wraps make to detect errors and interrupt make as soon as
# possible.
#
# When running jobs in parallel, the first level of make does not stop
# immediately other jobs when one has an error, leading to wait a long time
# before reporting the final error. This can be hard to go up the output to
# search for the real error.
#
# The stderr of make is redirected to scan it for errors and interrupt make
# sub-process. However this leads to further issues.
#
# - To interrupted sub-process and all its process tree, it is necessary in
# some situations to kill the complete process group. However doing so will
# kill this script and its parent process. So the sub-process is put in its own
# process group so that eventually all processes in it can be interrupted.
#
# - If the make sub-process tries to access the console (ncurses for example),
# it will either stop or won't be able to read from stdin. This is because
# the new process group is in the background. So we need to put it in the
# foreground by changing the process group associated with the console (by
# calling tcsetpgrp).
#
# - If the process group is stopped (Ctrl+Z), the parent shell will not take
# control, thus the user won't be able to do anything. When we detect this
# situation, we put back this script in the foreground, then propagate the stop
# to our parent shell script.
#
# -If the make sub-process is in a disk wait operation (uninterruptible wait)
# while Ctrl-Z is typed, this script is not notified by a SIGCHLD despite the
# fact that all processes in the make sub-process group are stopped. When this
# happens, the make sub-process is still the foreground, but stopped while
# in io wait, indicated by a 'D+' state in 'ps' output. I don't see any
# solution for the moment and it seems not related with this script because
# the same behaviour is observed when make is executed from bash directly.
# However, putting a shell as parent of make and so child of this script
# seems eliminating this issue because the shell will rarely be in a disk wait.
#
# - When we are resumed for execution, we put again the make sub-process in the
# foreground.
#
# The make sub-process is put in the foreground only if we were in the
# foreground in the first place.
# We also remember which process group shall be put as foreground at the end
#

import sys, os, logging
import subprocess
import signal
import time
import re

#===============================================================================
#===============================================================================
class Job:
    def __init__(self, jobCtrl):
        self.jobCtrl = jobCtrl
        self.process = None
        self.pid = -1
        self.pgid = -1
        self.status = -1
        self.stopped = False

    # Called in child process before 'exec' is done
    def _preExec(self):
        # Set process group
        logging.debug("CHILD: setpgid(0, 0)")
        os.setpgid(0, 0)
        if self.jobCtrl.foreground:
            logging.debug("CHILD: tcsetpgrp(0, %d)", os.getpgrp())
            os.tcsetpgrp(0, os.getpgrp())

        # Restore signal to default values
        signal.signal(signal.SIGINT, signal.SIG_DFL)
        signal.signal(signal.SIGTERM, signal.SIG_DFL)
        signal.signal(signal.SIGTTOU, signal.SIG_DFL)
        signal.signal(signal.SIGTTIN, signal.SIG_DFL)
        signal.signal(signal.SIGTSTP, signal.SIG_DFL)
        signal.signal(signal.SIGCHLD, signal.SIG_DFL)
        signal.signal(signal.SIGCONT, signal.SIG_DFL)

    # Launch the job process
    def launch(self, cmdline, stdin=None, stdout=None, stderr=None, env=None):
        # Start sub-process, see in header why we use a shell
        self.process = subprocess.Popen(cmdline,
                stdin=stdin, stdout=stdout, stderr=stderr,
                preexec_fn=self._preExec, shell=True, env=env,
                universal_newlines=True, close_fds=False)
        # Get information (don't call os.getpgid() because of a race condition
        # with the child)
        self.pid = self.process.pid
        self.pgid = self.pid

    # Interrupt process, then everyone in the process group, then kill
    def kill(self):
        try:
            time.sleep(0.2)
            logging.debug("kill(%d, SIGINT)", self.pid)
            os.kill(self.pid, signal.SIGINT)
            time.sleep(0.2)
            logging.debug("killpg(%d, SIGINT)", self.pgid)
            os.killpg(self.pgid, signal.SIGINT)
            time.sleep(0.2)
            logging.debug("killpg(%d, SIGTERM)", self.pgid)
            os.killpg(self.pgid, signal.SIGTERM)
            time.sleep(0.2)
            logging.debug("killpg(%d, SIGKILL)", self.pgid)
            os.killpg(self.pgid, signal.SIGKILL)
        except OSError as ex:
            logging.debug("OSError: %s", str(ex))

    # Update status after a succesful 'wait' operation
    def updateStatus(self, status):
        if os.WIFSTOPPED(status):
            logging.debug("STOPPED")
            self.stopped = True
        elif os.WIFCONTINUED(status):
            logging.debug("CONTINUED")
            self.stopped = False
        elif os.WIFSIGNALED(status):
            logging.debug("SIGNALED")
            self.process.returncode = -os.WTERMSIG(status)
        elif os.WIFEXITED(status):
            logging.debug("EXITED")
            self.process.returncode = os.WEXITSTATUS(status)

#===============================================================================
#===============================================================================
class JobCtrl:
    def __init__(self):
        # Remember which process group is associated with terminal
        self.tcpgrp = os.tcgetpgrp(0)
        self.foreground = (self.tcpgrp == os.getpgrp())
        logging.debug("tcpgrp=%d foreground=%d", self.tcpgrp, self.foreground)
        self.job = Job(self)

    def signalHandler(self, signo, _frame):
        logging.debug("signalHandler: signo=%d", signo)
        if signo == signal.SIGINT or signo == signal.SIGTERM:
            self.job.kill()

        elif signo == signal.SIGCHLD:
            # Get status of child
            try:
                (pid, status) = os.waitpid(self.job.pid,
                        os.WNOHANG + os.WCONTINUED + os.WUNTRACED)
            except OSError as ex:
                # Simulate success in case of error (very rare case...)
                logging.debug("waitpid: %s", str(ex))
                pid = self.job.pid
                status = 512
            logging.debug("waitpid: pid=%d status=%s", pid, status)
            self.job.updateStatus(status)

            if self.job.stopped:
                # If sub-process was associated with console, change it to us
                if os.tcgetpgrp(0) == self.job.pgid:
                    logging.debug("tcsetpgrp(0, %d)", os.getpgrp())
                    os.tcsetpgrp(0, os.getpgrp())
                # Propagate the stop to our process group
                logging.debug("killpg(0, SIGSTOP)")
                os.killpg(0, signal.SIGSTOP)

        elif signo == signal.SIGCONT:
            # If we are associated with console, change it to sub-process
            self.tcpgrp = os.tcgetpgrp(0)
            self.foreground = (self.tcpgrp == os.getpgrp())
            logging.debug("tcpgrp=%d foreground=%d", self.tcpgrp, self.foreground)
            if self.foreground:
                logging.debug("tcsetpgrp(0, %d)", self.job.pgid)
                os.tcsetpgrp(0, self.job.pgid)
            # Propagate continue to sub-process
            logging.debug("killpg(%d, SIGCONT)", self.job.pgid)
            os.killpg(self.job.pgid, signal.SIGCONT)

#===============================================================================
# Main function.
#===============================================================================
def main():
    # Setup logging
    setupLog()

    makeProg = os.environ.get("MAKE", "make")

    # Put in an environment variable the command line so we can find it
    os.environ["ALCHEMAKE_CMDLINE"] = " ".join([makeProg] + sys.argv[1:])

    # If not on a terminal, do NOT use job control, simply execute make...
    if not os.isatty(0):
        logging.warning("Not using job control")
        process = subprocess.Popen([makeProg] + sys.argv[1:], shell=False, close_fds=False)
        process.wait()
        sys.exit(process.returncode)
        return

    # Create our job control object
    jobCtrl = JobCtrl()

    # Try to exit silently in case of interrupts...
    signal.signal(signal.SIGINT, jobCtrl.signalHandler)
    signal.signal(signal.SIGTERM, jobCtrl.signalHandler)

    # Job control
    signal.signal(signal.SIGTTOU, signal.SIG_IGN)
    signal.signal(signal.SIGTTIN, signal.SIG_IGN)
    signal.signal(signal.SIGTSTP, signal.SIG_IGN)
    signal.signal(signal.SIGCHLD, jobCtrl.signalHandler)
    signal.signal(signal.SIGCONT, jobCtrl.signalHandler)

    # Only redirect stderr (redirecting stdout causes issues if a child process
    # wants to use the terminal, like ncurses)
    # Force error messages of sub processes to English, keeping encoding to UTF-8
    # LANG=C.UTF8 does NOT work as expected (messages are still in original locale)
    env = os.environ
    env["LC_MESSAGES"] = "C"
    env["LC_TIME"] = "C"
    cmdline = makeProg
    for arg in sys.argv[1:]:
        cmdline += " " + arg
    jobCtrl.job.launch(cmdline, stderr=subprocess.PIPE, env=env)

    # Read from stderr redirected in a pipe
    # only catch top level makefile errors (sub-make files error will eventually
    # generate a top level error)
    reError1 = re.compile(r"make: \*\*\* No rule to make target .*")
    reError2 = re.compile(r"make: \*\*\* \[[^\[\]]*\] Error [0-9]+")
    errorDetected = False
    while True:
        try:
            # Empty line means EOF detected, so exit loop
            line = jobCtrl.job.process.stderr.readline()
            if len(line) == 0:
                logging.debug("EOF detected")
                break
            if not errorDetected:
                sys.stderr.write(line)
            # Check for make error
            if reError1.match(line) or reError2.match(line):
                logging.debug("error detected")
                errorDetected = True
                jobCtrl.job.kill()
        except IOError:
            # Will occur when interrupted during read, an EOF will be read next
            pass

    # Only print message once at the end
    if errorDetected:
        sys.stderr.write("\n\033[31mMAKE ERROR DETECTED\n\033[00m")

    # Wait for sub-process to terminate
    logging.debug("wait sub-process")
    jobCtrl.job.process.wait()

    # Restore stuff
    if jobCtrl.tcpgrp != os.tcgetpgrp(0):
        try:
            logging.debug("tcsetpgrp(0, %d)", jobCtrl.tcpgrp)
            os.tcsetpgrp(0, jobCtrl.tcpgrp)
        except OSError:
            # Seems to occurs when launched in background and initial foreground
            # process is not there anymore, just ignore
            pass

    # Exit with same result as sub-process
    logging.debug("exit(%d)", jobCtrl.job.process.returncode)
    sys.exit(jobCtrl.job.process.returncode)

#===============================================================================
# Setup logging system.
#===============================================================================
def setupLog():
    logging.basicConfig(
        level=logging.WARNING,
        format="[%(levelname)s] %(message)s",
        stream=sys.stderr)
    logging.addLevelName(logging.CRITICAL, "C")
    logging.addLevelName(logging.ERROR, "E")
    logging.addLevelName(logging.WARNING, "W")
    logging.addLevelName(logging.INFO, "I")
    logging.addLevelName(logging.DEBUG, "D")

    # Setup log level
    logging.getLogger().setLevel(logging.WARNING)

#===============================================================================
# Entry point.
#===============================================================================
if __name__ == "__main__":
    main()
