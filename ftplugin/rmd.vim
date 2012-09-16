"  This program is free software; you can redistribute it and/or modify
"  it under the terms of the GNU General Public License as published by
"  the Free Software Foundation; either version 2 of the License, or
"  (at your option) any later version.
"
"  This program is distributed in the hope that it will be useful,
"  but WITHOUT ANY WARRANTY; without even the implied warranty of
"  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
"  GNU General Public License for more details.
"
"  A copy of the GNU General Public License is available at
"  http://www.r-project.org/Licenses/

"==========================================================================
" ftplugin for Rmd files
"
" Authors: Jakson Alves de Aquino <jalvesaq@gmail.com>
"          Jose Claudio Faria
"          Alex Zvoleff (adjusting for rmd by Michel Kuhlmann)
"
"==========================================================================

" Only do this when not yet done for this buffer
if exists("b:did_rmd_ftplugin") || exists("disable_r_ftplugin")
    finish
endif

" Don't load another plugin for this buffer
let b:did_rmd_ftplugin = 1

let s:cpo_save = &cpo
set cpo&vim

" Enables pandoc if it is installed
runtime ftplugin/pandoc.vim

" Source scripts common to R, Rrst, Rnoweb, Rhelp and Rdoc:
runtime r-plugin/common_global.vim
if exists("g:rplugin_failed")
    finish
endif

" Some buffer variables common to R, Rmd, Rrst, Rnoweb, Rhelp and Rdoc need to
" be defined after the global ones:
runtime r-plugin/common_buffer.vim

function! RmdIsInRCode()
    let curline = line(".")
    let chunkline = search("^```[ ]*{r", "bncW")
    call cursor(chunkline)
    let docline = search("^```$", "ncW")
    call cursor(curline)
    if 0 < chunkline && chunkline < curline && curline < docline
        return 1
    else
        return 0
    endif
endfunction

function! RmdPreviousChunk() range
    let rg = range(a:firstline, a:lastline)
    let chunk = len(rg)
    for var in range(1, chunk)
        let curline = line(".")
        if RmdIsInRCode()
            let i = search("^``` [ ]*{r", "bnW")
            if i != 0
                call cursor(i-1, 1)
            endif
        endif
        let i = search("^```[ ]*{r", "bnW")
        if i == 0
            call cursor(curline, 1)
            call RWarningMsg("There is no previous R code chunk to go.")
            return
        else
            call cursor(i+1, 1)
        endif
    endfor
    return
endfunction

function! RmdNextChunk() range
    let rg = range(a:firstline, a:lastline)
    let chunk = len(rg)
    for var in range(1, chunk)
        let i = search("^```[ ]*{r", "nW")
        if i == 0
            call RWarningMsg("There is no next R code chunk to go.")
            return
        else
            call cursor(i+1, 1)
        endif
    endfor
    return
endfunction

function! RMakePDF(t)
    update
    call RSetWD()
    let pdfcmd = "vim.interlace.rmd('" . expand("%:t") . "'"
    let pdfcmd = pdfcmd . ", pdfout = '" . a:t  . "'"
    if exists("g:vimrplugin_rmdcompiler")
        let pdfcmd = pdfcmd . ", compiler='" . g:vimrplugin_rmdcompiler . "'"
    endif
    if exists("g:vimrplugin_knitargs")
        let pdfcmd = pdfcmd . ", " . g:vimrplugin_knitargs
    endif
    if exists("g:vimrplugin_rmd2pdfpath")
        pdfcmd = pdfcmd . ", rmd2pdfpath='" . g:vimrplugin_rmd2pdf_path . "'"
    endif
    if exists("g:vimrplugin_pandoc_args")
        let pdfcmd = pdfcmd . ", pandoc_args = '" . g:vimrplugin_pandoc_args . "'"
    endif
    let pdfcmd = pdfcmd . ")"
    let b:needsnewomnilist = 1
    let ok = SendCmdToR(pdfcmd)
    if ok == 0
        return
    endif
endfunction  

" Send Rmd chunk to R
function! SendChunkToR(e, m)
    if RmdIsInRCode() == 0
        call RWarningMsg("Not inside an R code chunk.")
        return
    endif
    let chunkline = search("^```[ ]*{r", "bncW") + 1
    let docline = search("^```", "ncW") - 1
    let lines = getline(chunkline, docline)
    let ok = RSourceLines(lines, a:e)
    if ok == 0
        return
    endif
    if a:m == "down"
        call RmdNextChunk()
    endif  
endfunction

" knit the current buffer content
function! RKnit()
    update
    let b:needsnewomnilist = 1
    call RSetWD()
    call SendCmdToR('require(knitr); knit("' . expand("%:t") . '")')
endfunction

"==========================================================================
" Key bindings and menu items

call RCreateStartMaps()
call RCreateEditMaps()
call RCreateSendMaps()
call RControlMaps()
call RCreateMaps("nvi", '<Plug>RSetwd',        'rd', ':call RSetWD()')

" Only .Rmd files use these functions:
call RCreateMaps("nvi", '<Plug>RKnit',        'kn', ':call RKnit()')
call RCreateMaps("nvi", '<Plug>RMakePDFK',    'kp', ':call RMakePDF("latex")')
call RCreateMaps("nvi", '<Plug>RMakePDFK',    'kl', ':call RMakePDF("beamer")')
call RCreateMaps("nvi", '<Plug>RIndent',      'si', ':call RmdToggleIndentSty()')
call RCreateMaps("ni",  '<Plug>RSendChunk',   'cc', ':call SendChunkToR("silent", "stay")')
call RCreateMaps("ni",  '<Plug>RESendChunk',  'ce', ':call SendChunkToR("echo", "stay")')
call RCreateMaps("ni",  '<Plug>RDSendChunk',  'cd', ':call SendChunkToR("silent", "down")')
call RCreateMaps("ni",  '<Plug>REDSendChunk', 'ca', ':call SendChunkToR("echo", "down")')
nmap <buffer><silent> gn :call RmdNextChunk()<CR>
nmap <buffer><silent> gN :call RmdPreviousChunk()<CR>

" Menu R
if has("gui_running")
    call MakeRMenu()
endif

let &cpo = s:cpo_save
unlet s:cpo_save