#!/usr/bin/env python3
"""
fix_labels.py - Rename all assembly labels >= 9 chars to <= 8 chars
in gsh's 22 ORCA/M .asm files.

Cross-file labels (exported symbols, DATA segment vars accessed via 'using')
are renamed consistently across all files.
"""
import re, os, sys

BUILD_MODS = [
    'main', 'shell', 'history', 'prompt', 'cmd', 'expand', 'invoke',
    'shellutil', 'builtin', 'hash', 'alias', 'dir', 'shellvar', 'jobs',
    'sv', 'stdio', 'orca', 'edit', 'term', 'bufpool', 'mmdebug'
]

# Hand-crafted rename table for all long labels.
# Keys are original names; values are <= 8 char replacements.
# Ordered to avoid conflicts: longer names first so we don't partially rename.
RENAMES = {
    # === Cross-file exported entry points ===
    'InsertHistory': 'InsrtHst',  # history.asm -> edit.asm
    'PrintHistory':  'PrntHist',  # history.asm -> builtin.asm
    'InitHistory':   'InitHist',  # history.asm -> shell.asm
    'NextHistory':   'NextHist',  # history.asm -> edit.asm
    'PrevHistory':   'PrevHist',  # history.asm -> edit.asm
    'ReadHistory':   'ReadHist',  # history.asm -> shell.asm
    'SaveHistory':   'SaveHist',  # history.asm -> shell.asm
    'WritePrompt':   'WrtPrmpt',  # prompt.asm  -> edit.asm, shell.asm
    'GetCmdLine':    'GetCmdLn',  # edit.asm    -> shell.asm
    'AppendHome':    'AppHome',   # shell.asm   -> history.asm
    'dispose_hash':  'dsp_hash',  # hash.asm    -> builtin.asm, shell.asm
    'expandalias':   'expAlias',  # alias.asm   -> cmd.asm
    'expandvars':    'expVars',   # expand.asm  -> cmd.asm
    'initalias':     'initals',   # alias.asm   -> shell.asm
    'findalias':     'fndAlias',  # alias.asm   -> builtin.asm, prompt.asm
    'InitDStack':    'InitDStk',  # dir.asm     -> shell.asm
    'path2tilde':    'pth2tild',  # dir.asm     -> prompt.asm
    'getpfxstr':     'getPfxS',   # dir.asm     -> builtin.asm, prompt.asm
    'IsBuiltin':     'IsBltin',   # builtin.asm -> invoke.asm
    'ShellExec':     'ShlExec',   # cmd.asm     -> builtin.asm, invoke.asm, shell.asm
    'awaitstatus':   'awtstats',  # cmd.asm     -> invoke.asm
    'removejentry':  'rmvJent',   # jobs.asm    -> cmd.asm
    'setstatus':     'setstat',   # jobs.asm    -> cmd.asm
    'jobkiller':     'jobkill',   # jobs.asm    -> shell.asm
    'pallocpipe':    'palcpipe',  # jobs.asm    -> invoke.asm
    'sv_colprint':   'sv_col',    # sv.asm      -> builtin.asm
    'sv_dispose':    'sv_disp',   # sv.asm      -> builtin.asm
    'errputchar':    'errptch',   # stdio.asm   -> builtin.asm, term.asm
    'lowercstr':     'lwrCstr',   # shellutil.asm -> edit.asm, hash.asm, jobs.asm
    'allocmaxline':  'alcMxln',   # bufpool.asm -> many files
    'freemaxline':   'frmaxln',   # bufpool.asm -> many files
    'maxline_size':  'mxlnsz',    # bufpool.asm -> many files
    'aliasname':     'aliasnm',   # builtin.asm -> alias.asm
    'builtintbl':    'blttbl',    # builtin.asm -> edit.asm
    'hash_numexe':   'hshnumex',  # hash.asm    -> builtin.asm, edit.asm
    'hash_paths':    'hshpths',   # hash.asm    -> builtin.asm, invoke.asm
    'hash_table':    'hshtbl',    # hash.asm    -> builtin.asm, edit.asm, invoke.asm
    'bindkeyfunc':   'bndkyfn',   # edit.asm    -> term.asm
    'completed':     'compl',     # edit.asm    -> cmd.asm
    'sg_ospeed':     'sg_ospd',   # term.asm    -> edit.asm
    'insertflag':    'insflag',   # term.asm    -> edit.asm
    'moveright':     'movergt',   # term.asm    -> edit.asm
    'cursoroff':     'cursoff',   # term.asm    -> edit.asm
    'clearscrn':     'clrscn',    # term.asm    -> builtin.asm, edit.asm
    'underline':     'undline',   # term.asm    -> prompt.asm
    'didReadTerm':   'didRdTm',   # term.asm    -> shell.asm
    'backward_char': 'bkwdch',   # edit.asm, term.asm (both define+use within)
    'forward_char':  'fwdch',    # edit.asm, term.asm (both define+use within)
    'down_history':  'dwnhist',  # edit.asm, term.asm
    'up_history':    'uphist',   # edit.asm, term.asm

    # === Cross-file DATA segment variables (accessed via 'using') ===
    # global DATA (shell.asm) - accessed from cmd.asm, builtin.asm, edit.asm, hash.asm, jobs.asm
    'exit_requested': 'exitreq',
    'signalled':      'sigflag',
    'done_init':      'doneinit',
    'cmdcontext':     'cmdctx',   # only used in shell.asm (not truly cross-file but in DATA)

    # HistoryData (history.asm) - accessed via 'using HistoryData'
    'HistoryData':   'HistData',
    'historyFN':     'histFN',
    'historyStr':    'histStr',
    'historyptr':    'histptr',
    'histvalptr':    'histvptr',
    'currenthist':   'curhist',
    'savehistStr':   'svhstStr',
    'svhisvalptr':   'svhvptr',

    # vardata (shellvar.asm) - accessed via 'using vardata'
    'varpushdsil':  'varpsdsl',
    'varkeepquote': 'varkpqt',
    'varoldpmode':  'varopm',
    'varnewline':   'varnewln',
    'varnoglob':    'varnogl',
    'varnobeep':    'varnobt',
    'varignore':    'varignr',
    'vardirexec':   'vardirx',

    # AliasTable (alias.asm) -> shell.asm
    'AliasTable':   'AliTbl',

    # === Local labels - shell.asm ===
    'cmdbuflen':    'cmdbflen',
    'dummyshell':   'dmyshell',
    'fastskip1':    'fskip1',
    'fastskip2':    'fskip2',
    'fastskip5':    'fskip5',
    'nologin_init': 'nologin',
    'endpathconv':  'epthcnv',
    'nopathconv':   'npthcnv',
    'etcglogin':    'etcglog',
    'donekiller':   'dkiller',
    'lastabort':    'labort',
    'gshrcName':    'gshrcNm',
    'gloginName':   'glogNm',
    'TempResultBuf': 'TmpRBuf',   # each file has its own local copy
    'TempRBlen':    'TmpRBln',    # each file has its own local copy
    'RVexpflag':    'RVxflag',    # shellutil.asm + shellvar.asm (both define independently)

    # === Local labels - history.asm ===
    'CloseParm':    'ClsParm',    # local to history.asm and invoke.asm (independent copies)
    'CreateParm':   'CrtParm',
    'DestroyParm':  'DstParm',
    'WriteCRRef':   'WrtCRRf',
    'WriteParm':    'WrtParm',    # history.asm and stdio.asm (independent)
    'doneclose':    'donclos',
    'dummyhistory': 'dmyhist',
    'ReadTrans':    'RdTrans',

    # === Local labels - prompt.asm ===
    'dummyprompt':  'dmyprmt',
    'dfltPrompt':   'dfltPmt',
    'donemark2':    'dnmrk2',
    'parseprompt':  'prsepmt',
    'backspace':    'bkspc',
    'pstandend':    'pstdend',
    'pstandout':    'pstdout',
    'punderend':    'pundend',
    'punderline':   'pundln',
    'precmdstr':    'precstr',
    'promptgsbuf':  'pmtgsbf',
    'promptloop':   'pmtloop',
    'promptname':   'pmtname',
    'usergsbuf':    'usrgsbf',

    # === Local labels - cmd.asm ===
    'SINGQUOTE':    'SNGLQT',
    'T_GTGTAMP':    'T_GTAMP',   # 7 chars
    'case_gtgt':    'cs_gtgt',
    'case_inquote': 'cs_inqt',
    'case_inword':  'cs_inwd',
    'case_neutral': 'cs_neut',
    'case_single':  'cs_sngl',
    'digits2or3':   'dig2or3',   # also in jobs.asm (independent copy)
    'errappend':    'errapp',
    'found_end':    'fnd_end',
    'found_start':  'fnd_strt',
    'godonewait':   'godwait',
    'otherwait':    'othwait',
    'pname_text':   'pnmtxt',
    'ptr_envexp':   'ptrenvx',
    'restoresigh':  'rstsigh',
    'set_value':    'setval',    # also in jobs.asm (independent)
    'startquote':   'strtqt',
    'startsingle':  'strtsngl',
    'tok_error':    'tokerr',
    'tok_gtamp':    'tokgtam',
    'tok_gtgtamp':  'tokgtgt',
    'waitstatus':   'waitsts',    # also in jobs.asm (independent)
    'bump_strt':    'bmpstrt',

    # === Local labels - expand.asm ===
    'InitWCParm':   'InitWCP',
    'InitWCPath':   'IniWCPth',
    'ReadVarPB':    'RdVarPB',   # also in term.asm (independent)
    'braceexpand':  'brcexp',
    'braceloop':    'brcloop',
    'chkvarslash':  'chkvrsl',
    'doneflush':    'dnflush',
    'dummyexpand':  'dmyexp',
    'e_getbyte':    'egtbyte',
    'e_putbyte':    'eptbyte',
    'exp_mutex':    'expmtx',
    'expdouble':    'expdbl',
    'expsingle':    'expsngl',
    'flushloop':    'flshlp',
    'g_getbyte':    'ggtbyte',
    'g_putbyte':    'gptbyte',
    'g_putspecial': 'gptspec',
    'glob_mutex':   'glbmtx',
    'globoutta':    'glbout',
    'grabbingword': 'grbbwrd',
    'grabdouble':   'grabdbl',
    'grabsingle':   'grabsngl',
    'grabslash':    'grabslsh',
    'nooverflow':   'novflow',
    'nothingfound': 'nthnfnd',
    'outtahere':    'outhere',
    'ovflwreturn':  'ovflret',
    'shallweglob':  'shlwglb',
    'skipdeglob':   'skpdglb',
    'stdinexpand':  'stdinex',
    'valueresult':  'valres',

    # === Local labels - invoke.asm ===
    'GRecAuxType':  'GRecAux',   # also in builtin.asm (independent)
    'GRecFileType': 'GRecFT',    # also in builtin.asm (independent)
    'RedirectApp':  'RdrApp',
    'RedirectDev':  'RdrDev',
    'RedirectFile': 'RdrFile',
    'RedirectParm': 'RdrParm',
    '_pipeout2':    '_pipout2',
    '_semaphore':   '_semph',
    'clean_exit':   'clnexit',
    'dummyinvoke':  'dmyinvk',
    'errinfork':    'errfork',
    'fork_mutex':   'forkmtx',
    'forkbuiltin':  'frkbltn',
    'info_mutex':   'infomtx',
    'nfcleanup':    'nfclnup',
    'noforkbuiltin':'nofrkbt',
    'postfork2':    'pstfrk2',
    'postfork3':    'pstfrk3',
    'postfork4':    'pstfrk4',
    'postfork4a':   'pstfrk4a',
    'postfork5':    'pstfrk5',
    'postfork6':    'pstfrk6',
    'skipfrarg':    'skpfarg',
    'trybuiltin':   'trybltn',

    # === Local labels - shellutil.asm ===
    'dummyshellutil': 'dmyshlu',
    'memglobal':    'memglbl',

    # === Local labels - builtin.asm ===
    'BuiltinData':  'BltnData',
    'bindkeyname':  'bndkynm',
    'builtinloop':  'bltloop',
    'chdirname':    'chdrnm',
    'check4debug':  'chkdbug',
    'chkbuiltin':   'chkbltn',
    'clearname':    'clrnm',
    'donewline':    'dnnwln',
    'dummybuiltin': 'dmybltn',
    'exportname':   'exptnm',
    'foundbuiltin': 'fndbltn',
    'foundhash':    'fndhash',
    'globaldebug':  'glbldbg',
    'kvmerrstr':    'kvmers',
    'p_command':    'p_cmd',     # also in jobs.asm (independent)
    'p_friends':    'p_frnds',   # also in jobs.asm (independent)
    'prefixmutex':  'prfxmtx',
    'pushdname':    'psdname',
    'rehashname':   'rhashnm',
    'setbugname':   'setbugnm',
    'setenvname':   'setenvnm',
    'setprefix':    'setprfx',
    'showusage':    'shwusge',   # appears in multiple files independently
    'sourcename':   'srcnm',
    'unaliasname':  'unlsnm',
    'unhashname':   'unhashnm',
    'unsetname':    'unsetnm',
    'whichmutex':   'whchmtx',
    'whichname':    'whichnm',

    # === Local labels - hash.asm ===
    'DRecAccess':   'DRecAcc',
    'DRecAuxType':  'DRecAux',
    'DRecBlockCnt': 'DRecBlk',
    'DRecCreate':   'DRecCrt',
    'DRecEntry':    'DRecEnt',
    'DRecFileType': 'DRecFT',
    'EPinputPath':  'EPinPth',
    'EPoutputPath': 'EPoutPth',
    'ORecAccess':   'ORecAcc',
    'TempRBname':   'TmpRBnm',
    'dir_search':   'dirsch',
    'dispose_table':'dsp_tbl',
    'dummyhash':    'dmyhash',
    'filesdone':    'filsdon',
    'fn_dirNum':    'fn_dnum',
    'free_files':   'frfiles',
    'full_path':    'fullpth',
    'gotspace0':    'gtspc0',
    'gotspace1':    'gtspc1',
    'gotspace2':    'gtspc2',
    'gotspace3':    'gtspc3',
    'hash_files':   'hashfls',
    'hashmutex':    'hashmtx',
    'nextpath1':    'nxtpth1',
    'nextpath2':    'nxtpth2',
    'nopatherr':    'noptherr',
    'numEntries':   'numEntr',
    'tn_dirNum':    'tn_dnum',
    'toomanyerr':   'tmnyerr',

    # === Local labels - alias.asm ===
    'AliasData':    'AliData',
    'AliasMutex':   'AliMtx',
    'backstabber':  'bkstab',
    'buildalias':   'bldals',
    'doubquoter':   'dblqtr',
    'dummyalias':   'dmyals',
    'eatleader':    'eatldr',
    'hashalias':    'hashals',
    'makeword1':    'mkword1',
    'nextalias':    'nxtals',
    'removealias':  'rmvAls',
    'searchloop':   'srchloop',
    'singquoter':   'snglqtr',
    'startalias':   'strtals',
    'stringend':    'strend',

    # === Local labels - dir.asm ===
    'checkhome':    'chkhome',
    'errbadnum':    'errbdnm',
    'notfound2':    'ntfnd2',
    'showshort':    'shwshrt',
    'skipshorten':  'skpshtn',

    # === Local labels - shellvar.asm ===
    'ReadSetVar':   'RdSetVar',
    'ResultBuf':    'ResBuf',    # also in edit.asm (independent)
    'UnsetName':    'UnsetNm',
    'direxecname':  'dirxnm',
    'dummyshellvar':'dmysvr',
    'evvaltblsz':   'evvltsz',
    'idxExport':    'idxExpt',
    'ignorename':   'ignrnm',
    'ignoreofstr':  'ignofs',
    'keepquotename':'kpqtnm',
    'needshift':    'ndshift',
    'newlinename':  'nwlnnm',
    'nobeepname':   'nbepnm',
    'nobeepstr':    'nbepstr',
    'nodirexecstr': 'ndxstr',
    'noglobname':   'noglbnm',
    'noglobstr':    'noglbstr',
    'nonewlinestr': 'nonwlns',
    'oldpathmodestr':'oldpms',
    'oldpmodename': 'oldpmnm',
    'orcastyle':    'orcasty',
    'prnameval':    'prnmval',
    'pushdsilentstr':'psdsstr',
    'pushdsilname': 'psdsnam',
    'showonevar':   'shwonev',
    'startshow':    'strtshow',
    'unixstyle':    'unixsty',
    'updatevars':   'updvars',
    'varechoname':  'varechn',
    'varechoxname': 'varechxn',
    'varexitcode':  'varexcd',

    # === Local labels - jobs.asm ===
    'PINTERRUPTED': 'PINTRPT',
    'PNEEDNOTE':    'PNDNOTE',
    'PREPORTED':    'PRPTD',
    'PSIGNALED':    'PSIGNLD',
    'dummyjobs':    'dmyjobs',
    'lookfound':    'lkfound',
    'ohshitnum':    'ohshnum',
    'plistmutex':   'plistmtx',
    'pmaxindex':    'pmaxidx',
    'pprevious':    'pprevis',
    'sigotherstr':  'sigothrs',
    'sigttinstr':   'sigtins',
    'sigttoustr':   'sigtous',
    'statohshit':   'statohsh',
    'valstat_text': 'valstxt',

    # === Local labels - sv.asm ===
    'mkidxloop':    'mkidxlp',
    'nextprint':    'nxtprnt',
    'nextprint0':   'nxtprnt0',
    'offtblmutex':  'offtbmtx',
    'printloop':    'prntloop',

    # === Local labels - stdio.asm ===
    'dummystdio':   'dmystdio',
    'errWriteParm': 'errWPrm',
    'errstream':    'errstm',
    'flushparm':    'flshprm',
    'inReadParm':   'inRdPrm',
    'inrequest':    'inreq',

    # === Local labels - orca.asm ===
    'MAXPARMBUF':   'MAXPBUF',
    'argLoopPtr':   'argLpPt',
    'doloopend':    'dolpend',
    'donedealloc':  'dndeallc',
    'donewhile':    'dnwhile',
    'dummyorca':    'dmyorca',
    'editcommand':  'editcmd',
    'editorvar':    'editvar',
    'enoughparms':  'enghprm',
    'ep_inputPath': 'epinPth',
    'ep_outputPath':'epoutPth',
    'goteditvar':   'goedvar',
    'inLoopPtr':    'inLpPt',
    'nodelimit':    'nodlmt',
    'whileloop':    'whillp',

    # === Local labels - edit.asm ===
    'GetCmdLine':   'GetCmdLn',  # already listed above
    'VT100ARROW':   'VT100AR',
    'WORDGS_SIZE':  'WGSSIZE',
    'backward_delete_char': 'bkdlch',
    'backward_word':'bkwdwrd',
    'beginning_of_line':'bgnline',
    'breakloop':    'brkloop',
    'casebreak':    'csbrek',
    'casebreak0':   'csbrek0',
    'caseslash':    'csslash',
    'clear_screen': 'clrscr',
    'clearword':    'clrwrd',
    'cmdbackdel':   'cmdbkdl',
    'cmdbuflen':    'cmdbflen',  # independent gequ in edit.asm
    'cmdclearscrn': 'cmdclsc',
    'cmdclreol':    'cmdcleol',
    'cmdclrline':   'cmdclln',
    'cmdcursor':    'cmdcurs',
    'cmddelchar':   'cmddlch',
    'cmdleadin':    'cmdldin',
    'cmdleftword':  'cmdlwrd',
    'cmdnewline':   'cmdnwln',
    'cmdredraw':    'cmdrdraw',
    'cmdrightword': 'cmdrwrd',
    'complete_word':'compwrd',
    'defescmap':    'dfescmp',
    'delete_char':  'dltch',
    'dofignore':    'dofign',
    'domatcher':    'domatch',
    'dontdomatch':  'dntdmch',
    'dummyedit':    'dmyedit',
    'end_of_line':  'endline',
    'eq_endhash':   'eqendhsh',
    'filematch':    'filmatch',
    'filemdone':    'filmdone',
    'findstart':    'fndstrt',
    'findstart2':   'fndstrt2',
    'insertcmd':    'inscmd',
    'keybinddata':  'kbnddat',
    'keybindtab':   'kbndtbl',
    'kill_end_of_line': 'klleol',
    'kill_whole_line': 'kllwhl',
    'list_choices': 'lstchos',
    'newline_char': 'nlchr',
    'nextchar2':    'nxtch2',
    'nexthash0':    'nxthsh0',
    'nextslash':    'nxtslsh',
    'redisplay':    'redispl',
    'removeword':   'rmvwrd',
    'startbind':    'strtbnd',
    'toggle_cursor':'tglcurs',
    'undefined_char': 'undfch',
    'wordgs_text':  'wgstext',
    'wordgsbuf':    'wgsbuf',
    'wordmatch':    'wrdmatch',

    # === Local labels - term.asm ===
    'dummyresult':  'dmyres',
    'dummyterm':    'dmyterm',
    'hold_term_val':'hldtval',
    'ReadVarPB':    'RdVarPB',   # independent in term.asm

    # === Local labels - bufpool.asm ===
    'allocmaxline': 'alcMxln',  # already listed
    'dummybufpool': 'dmybfpl',
    'freemaxline':  'frmaxln',  # already listed
    'maxline_size': 'mxlnsz',   # already listed
    'pmaxlinemutex':'pmxlnmtx',

    # === Local labels - mmdebug.asm ===
    'dummymmdebug': 'dmymmdb',
}

def make_word_re(name):
    """Pattern that matches 'name' as a whole word."""
    return re.compile(r'\b' + re.escape(name) + r'\b')

def apply_renames(text, renames_sorted):
    """Apply rename map to text, longest names first to avoid partial matches."""
    for old, new in renames_sorted:
        text = make_word_re(old).sub(new, text)
    return text

def validate_renames():
    """Check for conflicts and length violations."""
    errors = []
    seen_values = {}
    for old, new in RENAMES.items():
        if len(new) > 8:
            errors.append(f"TOO LONG: {old} -> {new} ({len(new)} chars)")
        if new in seen_values and seen_values[new] != old:
            errors.append(f"CONFLICT: both {old} and {seen_values[new]} map to {new}")
        seen_values[new] = old
    return errors

if __name__ == '__main__':
    dry_run = '--dry-run' in sys.argv

    # Validate the rename table
    errors = validate_renames()
    if errors:
        print("ERRORS in rename table:")
        for e in errors:
            print(f"  {e}")
        sys.exit(1)

    # Sort by length descending to avoid partial replacement
    renames_sorted = sorted(RENAMES.items(), key=lambda x: -len(x[0]))

    # Process each file
    for mod in BUILD_MODS:
        fname = f'{mod}.asm'
        if not os.path.exists(fname):
            print(f"SKIP (not found): {fname}")
            continue

        with open(fname) as f:
            original = f.read()

        updated = apply_renames(original, renames_sorted)

        if updated == original:
            print(f"UNCHANGED: {fname}")
            continue

        # Count how many substitutions were made
        changes = sum(1 for old, _ in renames_sorted
                      if re.search(r'\b' + re.escape(old) + r'\b', original))

        if dry_run:
            print(f"WOULD CHANGE: {fname} ({changes} label types)")
        else:
            with open(fname, 'w') as f:
                f.write(updated)
            print(f"UPDATED: {fname} ({changes} label types)")

    if dry_run:
        print("\n(dry run - no files modified)")
    else:
        print("\nDone. Run 'make -f goldengate/build/phase6_gsh.mk' to test.")
