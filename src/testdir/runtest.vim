" This script is sourced while editing the .vim file with the tests.
" When the script is successful the .res file will be created.
" Errors are appended to the test.log file.
"
" To execute only specific test functions, add a second argument.  It will be
" matched against the names of the Test_ function.  E.g.:
"	../vim -u NONE -S runtest.vim test_channel.vim open_delay
" The output can be found in the "messages" file.
"
" If the environment variable $TEST_FILTER is set then only test functions
" matching this pattern are executed.  E.g. for sh/bash:
"     export TEST_FILTER=Test_channel
" For csh:
"     setenv TEST_FILTER Test_channel
"
" To ignore failure for tests that are known to fail in a certain environment,
" set $TEST_MAY_FAIL to a comma separated list of function names.  E.g. for
" sh/bash:
"     export TEST_MAY_FAIL=Test_channel_one,Test_channel_other
" The failure report will then not be included in the test.log file and
" "make test" will not fail.
"
" The test script may contain anything, only functions that start with
" "Test_" are special.  These will be invoked and should contain assert
" functions.  See test_assert.vim for an example.
"
" It is possible to source other files that contain "Test_" functions.  This
" can speed up testing, since Vim does not need to restart.  But be careful
" that the tests do not interfere with each other.
"
" If an error cannot be detected properly with an assert function add the
" error to the v:errors list:
"   call add(v:errors, 'test foo failed: Cannot find xyz')
"
" If preparation for each Test_ function is needed, define a SetUp function.
" It will be called before each Test_ function.
"
" If cleanup after each Test_ function is needed, define a TearDown function.
" It will be called after each Test_ function.
"
" When debugging a test it can be useful to add messages to v:errors:
"	call add(v:errors, "this happened")


" Without the +eval feature we can't run these tests, bail out.
so small.vim

" Check that the screen size is at least 24 x 80 characters.
if &lines < 24 || &columns < 80 
  let error = 'Screen size too small! Tests require at least 24 lines with 80 characters, got ' .. &lines .. ' lines with ' .. &columns .. ' characters'
  echoerr error
  split test.log
  $put =error
  write
  split messages
  call append(line('$'), '')
  call append(line('$'), 'From ' . expand('%') . ':')
  call append(line('$'), error)
  write
  qa!
endif

if has('reltime')
  let s:start_time = reltime()
endif

" Common with all tests on all systems.
source setup.vim

" For consistency run all tests with 'nocompatible' set.
" This also enables use of line continuation.
set nocp viminfo+=nviminfo

" Use utf-8 by default, instead of whatever the system default happens to be.
" Individual tests can overrule this at the top of the file and use
" g:orig_encoding if needed.
let g:orig_encoding = &encoding
set encoding=utf-8

" REDIR_TEST_TO_NULL has a very permissive SwapExists autocommand which is for
" the test_name.vim file itself. Replace it here with a more restrictive one,
" so we still catch mistakes.
let s:test_script_fname = expand('%')
au! SwapExists * call HandleSwapExists()
func HandleSwapExists()
  " Ignore finding a swap file for the test script (the user might be
  " editing it and do ":make test_name") and the output file.
  " Report finding another swap file and chose 'q' to avoid getting stuck.
  if expand('<afile>') == 'messages' || expand('<afile>') =~ s:test_script_fname
    let v:swapchoice = 'e'
  else
    call assert_report('Unexpected swap file: ' .. v:swapname)
    let v:swapchoice = 'q'
  endif
endfunc

" Avoid stopping at the "hit enter" prompt
set nomore

" Output all messages in English.
lang mess C

" Always use forward slashes.
set shellslash

let s:srcdir = expand('%:p:h:h')

" Prepare for calling test_garbagecollect_now().
let v:testing = 1

" Support function: get the alloc ID by name.
function GetAllocId(name)
  exe 'split ' . s:srcdir . '/alloc.h'
  let top = search('typedef enum')
  if top == 0
    call add(v:errors, 'typedef not found in alloc.h')
  endif
  let lnum = search('aid_' . a:name . ',')
  if lnum == 0
    call add(v:errors, 'Alloc ID ' . a:name . ' not defined')
  endif
  close
  return lnum - top - 1
endfunc

func RunTheTest(test)
  echo 'Executing ' . a:test
  if has('reltime')
    let func_start = reltime()
  endif

  " Avoid stopping at the "hit enter" prompt
  set nomore

  " Avoid a three second wait when a message is about to be overwritten by the
  " mode message.
  set noshowmode

  " Clear any overrides.
  call test_override('ALL', 0)

  " Some tests wipe out buffers.  To be consistent, always wipe out all
  " buffers.
  %bwipe!

  " The test may change the current directory. Save and restore the
  " directory after executing the test.
  let save_cwd = getcwd()

  if exists("*SetUp")
    try
      call SetUp()
    catch
      call add(v:errors, 'Caught exception in SetUp() before ' . a:test . ': ' . v:exception . ' @ ' . v:throwpoint)
    endtry
  endif

  if a:test =~ 'Test_nocatch_'
    " Function handles errors itself.  This avoids skipping commands after the
    " error.
    exe 'call ' . a:test
  else
    try
      au VimLeavePre * call EarlyExit(g:testfunc)
      exe 'call ' . a:test
      au! VimLeavePre
    catch /^\cskipped/
      call add(s:messages, '    Skipped')
      call add(s:skipped, 'SKIPPED ' . a:test . ': ' . substitute(v:exception, '^\S*\s\+', '',  ''))
    catch
      call add(v:errors, 'Caught exception in ' . a:test . ': ' . v:exception . ' @ ' . v:throwpoint)
    endtry
  endif

  " In case 'insertmode' was set and something went wrong, make sure it is
  " reset to avoid trouble with anything else.
  set noinsertmode

  if exists("*TearDown")
    try
      call TearDown()
    catch
      call add(v:errors, 'Caught exception in TearDown() after ' . a:test . ': ' . v:exception . ' @ ' . v:throwpoint)
    endtry
  endif

  " Clear any autocommands and put back the catch-all for SwapExists.
  au!
  au SwapExists * call HandleSwapExists()

  " Close any stray popup windows
  if has('popupwin')
    call popup_clear()
  endif

  " Close any extra tab pages and windows and make the current one not modified.
  while tabpagenr('$') > 1
    quit!
  endwhile

  while 1
    let wincount = winnr('$')
    if wincount == 1
      break
    endif
    bwipe!
    if wincount == winnr('$')
      " Did not manage to close a window.
      only!
      break
    endif
  endwhile

  exe 'cd ' . save_cwd

  let message = 'Executed ' . a:test
  if has('reltime')
    let message ..= ' in ' .. reltimestr(reltime(func_start)) .. ' seconds'
  endif
  call add(s:messages, message)
  let s:done += 1
endfunc

func AfterTheTest(func_name)
  if len(v:errors) > 0
    if match(s:may_fail_list, '^' .. a:func_name) >= 0
      let s:fail_expected += 1
      call add(s:errors_expected, 'Found errors in ' . g:testfunc . ':')
      call extend(s:errors_expected, v:errors)
    else
      let s:fail += 1
      call add(s:errors, 'Found errors in ' . g:testfunc . ':')
      call extend(s:errors, v:errors)
    endif
    let v:errors = []
  endif
endfunc

func EarlyExit(test)
  " It's OK for the test we use to test the quit detection.
  if a:test != 'Test_zz_quit_detected()'
    call add(v:errors, 'Test caused Vim to exit: ' . a:test)
  endif

  call FinishTesting()
endfunc

" This function can be called by a test if it wants to abort testing.
func FinishTesting()
  call AfterTheTest('')

  " Don't write viminfo on exit.
  set viminfo=

  " Clean up files created by setup.vim
  call delete('XfakeHOME', 'rf')

  if s:fail == 0 && s:fail_expected == 0
    " Success, create the .res file so that make knows it's done.
    exe 'split ' . fnamemodify(g:testname, ':r') . '.res'
    write
  endif

  if len(s:errors) > 0
    " Append errors to test.log
    split test.log
    call append(line('$'), '')
    call append(line('$'), 'From ' . g:testname . ':')
    call append(line('$'), s:errors)
    write
  endif

  if s:done == 0
    if s:filtered > 0
      let message = "NO tests match $TEST_FILTER: '" .. $TEST_FILTER .. "'"
    else
      let message = 'NO tests executed'
    endif
  else
    if s:filtered > 0
      call add(s:messages, "Filtered " .. s:filtered .. " tests with $TEST_FILTER")
    endif
    let message = 'Executed ' . s:done . (s:done > 1 ? ' tests' : ' test')
  endif
  if s:done > 0 && has('reltime')
    let message ..= ' in ' .. reltimestr(reltime(s:start_time)) .. ' seconds'
  endif
  echo message
  call add(s:messages, message)
  if s:fail > 0
    let message = s:fail . ' FAILED:'
    echo message
    call add(s:messages, message)
    call extend(s:messages, s:errors)
  endif
  if s:fail_expected > 0
    let message = s:fail_expected . ' FAILED (matching $TEST_MAY_FAIL):'
    echo message
    call add(s:messages, message)
    call extend(s:messages, s:errors_expected)
  endif

  " Add SKIPPED messages
  call extend(s:messages, s:skipped)

  " Append messages to the file "messages"
  split messages
  call append(line('$'), '')
  call append(line('$'), 'From ' . g:testname . ':')
  call append(line('$'), s:messages)
  write

  qall!
endfunc

" Source the test script.  First grab the file name, in case the script
" navigates away.  g:testname can be used by the tests.
let g:testname = expand('%')
let s:done = 0
let s:fail = 0
let s:fail_expected = 0
let s:errors = []
let s:errors_expected = []
let s:messages = []
let s:skipped = []
if expand('%') =~ 'test_vimscript.vim'
  " this test has intentional errors, don't use try/catch.
  source %
else
  try
    source %
  catch /^\cskipped/
    call add(s:messages, '    Skipped')
    call add(s:skipped, 'SKIPPED ' . expand('%') . ': ' . substitute(v:exception, '^\S*\s\+', '',  ''))
  catch
    let s:fail += 1
    call add(s:errors, 'Caught exception: ' . v:exception . ' @ ' . v:throwpoint)
  endtry
endif

" Names of flaky tests.
let s:flaky_tests = [
      \ 'Test_autocmd_SafeState()',
      \ 'Test_client_server()',
      \ 'Test_close_and_exit_cb()',
      \ 'Test_close_output_buffer()',
      \ 'Test_collapse_buffers()',
      \ 'Test_cwd()',
      \ 'Test_diff_screen()',
      \ 'Test_exit_callback_interval()',
      \ 'Test_map_timeout_with_timer_interrupt()',
      \ 'Test_out_cb()',
      \ 'Test_pipe_through_sort_all()',
      \ 'Test_pipe_through_sort_some()',
      \ 'Test_popup_and_window_resize()',
      \ 'Test_quoteplus()',
      \ 'Test_quotestar()',
      \ 'Test_reltime()',
      \ 'Test_state()',
      \ 'Test_terminal_composing_unicode()',
      \ 'Test_terminal_does_not_truncate_last_newlines()',
      \ 'Test_terminal_no_cmd()',
      \ 'Test_terminal_noblock()',
      \ 'Test_terminal_redir_file()',
      \ 'Test_termwinscroll()',
      \ 'Test_timer_oneshot()',
      \ 'Test_timer_paused()',
      \ 'Test_timer_repeat_many()',
      \ 'Test_timer_repeat_three()',
      \ 'Test_timer_stop_all_in_callback()',
      \ 'Test_timer_stop_in_callback()',
      \ 'Test_timer_with_partial_callback()',
      \ ]

" Locate Test_ functions and execute them.
redir @q
silent function /^Test_
redir END
let s:tests = split(substitute(@q, '\(function\|def\) \(\k*()\)', '\2', 'g'))

" If there is an extra argument filter the function names against it.
if argc() > 1
  let s:tests = filter(s:tests, 'v:val =~ argv(1)')
endif

" If the environment variable $TEST_FILTER is set then filter the function
" names against it.
let s:filtered = 0
if $TEST_FILTER != ''
  let s:filtered = len(s:tests)
  let s:tests = filter(s:tests, 'v:val =~ $TEST_FILTER')
  let s:filtered -= len(s:tests)
endif

let s:may_fail_list = []
if $TEST_MAY_FAIL != ''
  " Split the list at commas and add () to make it match g:testfunc.
  let s:may_fail_list = split($TEST_MAY_FAIL, ',')->map({i, v -> v .. '()'})
endif

" Execute the tests in alphabetical order.
for g:testfunc in sort(s:tests)
  " Silence, please!
  set belloff=all
  let prev_error = ''
  let total_errors = []
  let g:run_nr = 1

  " A test can set g:test_is_flaky to retry running the test.
  let g:test_is_flaky = 0

  call RunTheTest(g:testfunc)

  " Repeat a flaky test.  Give up when:
  " - it fails again with the same message
  " - it fails five times (with a different message)
  if len(v:errors) > 0
        \ && (index(s:flaky_tests, g:testfunc) >= 0
        \      || g:test_is_flaky)
    while 1
      call add(s:messages, 'Found errors in ' . g:testfunc . ':')
      call extend(s:messages, v:errors)

      call add(total_errors, 'Run ' . g:run_nr . ':')
      call extend(total_errors, v:errors)

      if g:run_nr == 5 || prev_error == v:errors[0]
        call add(total_errors, 'Flaky test failed too often, giving up')
        let v:errors = total_errors
        if has('gui_macvim')
          " MacVim's currently doesn't always pass these tests. Make these
          " tests pending for now before a more proper fix is implemented.
          call extend(s:messages, [
                \ 'Flaky test failed too often, giving up',
                \ 'MacVim marked ' . g:testfunc . ' as pending',
                \ ])
          let v:errors = []
        endif
        break
      endif

      call add(s:messages, 'Flaky test failed, running it again')

      " Flakiness is often caused by the system being very busy.  Sleep a
      " couple of seconds to have a higher chance of succeeding the second
      " time.
      sleep 2

      let prev_error = v:errors[0]
      let v:errors = []
      let g:run_nr += 1

      call RunTheTest(g:testfunc)

      if len(v:errors) == 0
        " Test passed on rerun.
        break
      endif
    endwhile
  endif

  call AfterTheTest(g:testfunc)
endfor

call FinishTesting()

" vim: shiftwidth=2 sts=2 expandtab
