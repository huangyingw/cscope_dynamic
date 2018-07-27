" Section: Internal script variables {{{1
"
let s:big_init = 0
let s:big_last_update = 0
let s:big_min_interval = 10
let s:big_update = 0
let s:full_update_force = 0
let s:lock_file = ".cscopedb.lock"
let s:resolve_links = 1
let s:small_file = "cscope.small"
let s:small_file_dict={}
let s:small_init = 0
let s:small_update = 0

" Vim global plugin for autoloading cscope databases.
" Last Change: Wed Jan 26 10:28:52 Jerusalem Standard Time 2011
" Maintainer: Michael Conrad Tadpol Tilsra <tadpol@tadpol.org>
" Revision: 0.5

if exists("loaded_autoload_cscope")
    finish
endif
let loaded_autoload_cscope = 1

" requirements, you must have these enabled or this is useless.
if(  !has('cscope') || !has('modify_fname') )
    finish
endif

let s:save_cpo = &cpo
set cpo&vim

"==
" Unload_csdb
"  drop cscope connections.
function s:Unload_csdb()
    if exists("b:csdbpath")
        if cscope_connection(3, "out", b:csdbpath)
            let save_csvb = &csverb
            set nocsverb
            exe "cs kill " . b:csdbpath
            set csverb
            let &csverb = save_csvb
        endif
    endif
endfunc

"
"==
" Cycle_csdb
"  cycle the loaded cscope db.
function s:Cycle_csdb()
    if exists("b:csdbpath")
        if cscope_connection(3, "out", b:csdbpath)
            return
            "it is already loaded. don't try to reload it.
        endif
    endif
    let newcsdbpath = Find_in_parent("cscope.out",Windowdir(),$HOME)
    "    echo "Found cscope.out at: " . newcsdbpath
    "    echo "Windowdir: " . Windowdir()
    if newcsdbpath != "Nothing"
        let b:csdbpath = newcsdbpath
        if !cscope_connection(3, "out", b:csdbpath)
            let save_csvb = &csverb
            set nocsverb
            exe "cs add " . b:csdbpath . "/cscope.out " . b:csdbpath
            let s:proj_file = b:csdbpath . "/files.proj"
            let s:big_file = b:csdbpath . "/cscope.out"
            let s:small_file = b:csdbpath . "/cscope.small"
            let s:lock_file = b:csdbpath . "/.cscopedb.lock"
            set csverb
            let &csverb = save_csvb
        endif
        "
    else " No cscope database, undo things. (someone rm-ed it or somesuch)
        call s:Unload_csdb()
    endif
endfunc

function! s:runShellCommand(cmd)
    " Use perl if we have it. Using :!<shell command>
    " breaks the tag stack for some reason.
    "
    if has('perl')
        silent execute "perl system('" . a:cmd . "')" | redraw!
    else
        silent execute "!" . a:cmd | redraw!
    endif
endfunction

" Add the file to the small DB file list. {{{2
" This moves the file to the small cscope DB and triggers an update
" of the necessary databases.
"
function! s:smallListUpdate(file)
    if (expand("%") =~ 'findresult')
        return
    endif

    let s:small_update = 1

    " If file moves to small DB then we also do a big DB update so
    " we don't end up with duplicate lookups.
    if s:resolve_links
        let path = fnamemodify(resolve(expand(a:file)), ":p:.")
    else
        let path = fnamemodify(expand(a:file), ":p:.")
    endif
    if !has_key(s:small_file_dict, path)
        let s:small_file_dict[path] = 1
        let s:big_update = 1
        call writefile(keys(s:small_file_dict), expand(s:small_file) . ".files")
    endif
endfunction

" Update any/all of the DBs {{{2
"
function! s:dbUpdate()
    if s:small_update != 1 && s:big_update != 1
        return
    endif

    if filereadable(expand(s:lock_file))
        return
    endif

    " Touch lock file synchronously
    call s:runShellCommand("touch ".s:lock_file)

    " Do small update first. We'll do big update
    " after the small updates are done.
    "
    if s:small_update == 1
        let cmd = ""
        let cmd .= "(cscope -kbR "
        if s:full_update_force
            let cmd .= "-u "
        else
            let cmd .= "-U "
        endif
        let cmd .= "-i".s:small_file.".files -f".s:small_file
        let cmd .= "; rm ".s:lock_file
        let cmd .= ") &>/dev/null &"

        let s:small_update = 2
        call s:runShellCommand(cmd)
    endif

    if localtime() > s:big_last_update + s:big_min_interval
        call UpdateProj()
        silent exec '!rm ' . s:lock_file
        let s:big_update = 2
        let s:big_last_update = localtime()
        let s:full_update_force = 0
    endif
endfunction

" Do a FULL DB update {{{2
"
function! s:dbFullUpdate()
    let s:big_update = 1
    if !empty(s:small_file_dict)
        let s:small_update = 1
    endif

    call s:dbUpdate()
endfunction

augroup cscopedb_augroup
    au!
    au BufWritePre * call <SID>smallListUpdate(expand("<afile>"))
    au BufWritePost * call <SID>dbUpdate()
    au FileChangedShellPost * call <SID>dbFullUpdate()
augroup END
" auto toggle the menu
augroup autoload_cscope
    au!
    au BufEnter *     call <SID>Cycle_csdb()
    au BufUnload *    call <SID>Unload_csdb()
augroup END

let &cpo = s:save_cpo
