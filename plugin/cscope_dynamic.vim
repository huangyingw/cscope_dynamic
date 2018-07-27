" Section: Internal script variables {{{1
"
let s:big_init = 0
let s:big_last_update = 0
let s:big_update = 0
let s:full_update_force = 0
let s:needs_reset = 0
let s:resolve_links = 1
let s:small_file_dict={}
let s:small_init = 0
let s:small_update = 0
let s:small_file = "cscope.small"
let s:lock_file = ".cscopedb.lock"

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

" If you set this to anything other than 1, the menu and macros will not be
" loaded.  Useful if you have your own that you like.  Or don't want my stuff
" clashing with any macros you've made.
if !exists("g:autocscope_menus")
    let g:autocscope_menus = 1
endif
"
"==
" Cycle_macros_menus
"  if there are cscope connections, activate that stuff.
"  Else toss it out.
"  TODO Maybe I should move this into a seperate plugin?
let s:menus_loaded = 0
function s:Cycle_macros_menus()
    if g:autocscope_menus != 1
        return
    endif
    if cscope_connection()
        if s:menus_loaded == 1
            return
        endif
        let s:menus_loaded = 1
        set csto=0
        set cst
        silent! map <unique> <C-\>s :cs find s <C-R>=expand("<cword>")<CR><CR>
        silent! map <unique> <C-\>g :cs find g <C-R>=expand("<cword>")<CR><CR>
        silent! map <unique> <C-\>d :cs find d <C-R>=expand("<cword>")<CR><CR>
        silent! map <unique> <C-\>c :cs find c <C-R>=expand("<cword>")<CR><CR>
        silent! map <unique> <C-\>t :cs find t <C-R>=expand("<cword>")<CR><CR>
        silent! map <unique> <C-\>e :cs find e <C-R>=expand("<cword>")<CR><CR>
        silent! map <unique> <C-\>f :cs find f <C-R>=expand("<cword>")<CR><CR>
        silent! map <unique> <C-\>i :cs find i <C-R>=expand("<cword>")<CR><CR>
        if has("menu")
            nmenu &Cscope.Find.Symbol<Tab><c-\\>s
                        \ :cs find s <C-R>=expand("<cword>")<CR><CR>
            nmenu &Cscope.Find.Definition<Tab><c-\\>g
                        \ :cs find g <C-R>=expand("<cword>")<CR><CR>
            nmenu &Cscope.Find.Called<Tab><c-\\>d
                        \ :cs find d <C-R>=expand("<cword>")<CR><CR>
            nmenu &Cscope.Find.Calling<Tab><c-\\>c
                        \ :cs find c <C-R>=expand("<cword>")<CR><CR>
            nmenu &Cscope.Find.Assignment<Tab><c-\\>t
                        \ :cs find t <C-R>=expand("<cword>")<CR><CR>
            nmenu &Cscope.Find.Egrep<Tab><c-\\>e
                        \ :cs find e <C-R>=expand("<cword>")<CR><CR>
            nmenu &Cscope.Find.File<Tab><c-\\>f
                        \ :cs find f <C-R>=expand("<cword>")<CR><CR>
            nmenu &Cscope.Find.Including<Tab><c-\\>i
                        \ :cs find i <C-R>=expand("<cword>")<CR><CR>
            "      nmenu &Cscope.Add :cs add
            "      nmenu &Cscope.Remove  :cs kill
            nmenu &Cscope.Reset :cs reset<cr>
            nmenu &Cscope.Show :cs show<cr>
            " Need to figure out how to do the add/remove. May end up writing
            " some container functions.  Or tossing them out, since this is supposed
            " to all be automatic.
        endif
    else
        let s:menus_loaded = 0
        set nocst
        silent! unmap <C-\>s
        silent! unmap <C-\>g
        silent! unmap <C-\>d
        silent! unmap <C-\>c
        silent! unmap <C-\>t
        silent! unmap <C-\>e
        silent! unmap <C-\>f
        silent! unmap <C-\>i
        if has("menu")  " would rather see if the menu exists, then remove...
            silent! nunmenu Cscope
        endif
    endif
endfunc
"
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

    " Limit how often a big DB update can occur.
    "
    if s:small_update != 1 && s:big_update == 1
        if localtime() < s:big_last_update + s:big_min_interval
            return
        endif
    endif

    let cmd = ""

    " Touch lock file synchronously
    call s:runShellCommand("touch ".s:lock_file)

    " Do small update first. We'll do big update
    " after the small updates are done.
    "
    if s:small_update == 1
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
    endif

    call s:runShellCommand(cmd)

    let s:needs_reset = 1
    if exists("*Cscope_dynamic_update_hook")
        call Cscope_dynamic_update_hook(1)
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
    au BufEnter *     call <SID>Cycle_csdb() | call <SID>Cycle_macros_menus()
    au BufUnload *    call <SID>Unload_csdb() | call <SID>Cycle_macros_menus()
augroup END

let &cpo = s:save_cpo
