#include "TOTVS.CH"
#include "FileIO.ch"
#define CRLF Chr(13)+Chr(10)

/*
Importante:
As bibliotecas necessarias para uso do exemplo lua_execindll.prw 
estao no diretorio bin/ do pacote, utilize de acordo com seu sistema operacional

bin/
|-- linux
|   |-- luacall.so
|   |-- socket.lua
|   `-- socket.so
`-- windows
    |-- lua54.dll
    |-- luacall.dll
    |-- socket.dll
    `-- socket.lua

*Para execucao dos exemplos as bibliotecas devem estar na pasta do SmartClient, 
pois sua localização eh obtida atraves da funcao getClientDir(), altere o caminho de acordo com sua necessidade.
*/

#define LUA_OPEN      1 // Abre conexao com o Lua via DLL
#define LUA_EXECFILE  2 // Executa o codigo Lua recebendo o caminho para um arquivo
#define LUA_EXECSTR   3 // Executa o codigo Lua recebendo um trecho de codigo
#define LUA_CLOSE     4 // Fecha conexao com o Lua

#define LUA_SRC_VAR_LUA_TLPP  1 // Intercambio de variaveis entre Lua e o TLPP
#define LUA_SRC_MATH          2 // Utilizando a biblioteca matematica do Lua
#define LUA_SRC_LOCALFILE     3 // Cria arquivo na estacao local
#define LUA_SRC_TCPSEND       4 // Conexao TCP utilizando o LuaSocket (socket.so)

#define MAX_BUFFER_DLL        512000 // Tamanho maximo do buffer para DLL/SO

/*/{Protheus.doc} TLuaExec
  Classe responsavel pela execucao de comandos Lua Script
  *Importante: Depende do arquivo luacall.so (Linux) ou luaexec.dll/lua54.dll (Windows)
  @author mansano@
  @since 30/12/2022
  @version 0.1
  /*/
class TLuaExec
	data nHandle
	data lConnected

	method connect()  // Conecta com a DLL e o motor do Lua Scripr
	method close()    // Encerra a conexao com o Lua e a DLL
	method setVar()   // Define nome/valor da variavel Lua
	method getVar()   // Recupera o valor da variavel Lua
	method execute()  // Executa trecho/arquivo Lua
	method execFile() // Executa arquivo .lua ou .luajit
	method saveSrc()  // Salva trecho de codigo fonte em arquivo
endClass

/*/{Protheus.doc} TLuaExec:connect
  Conecta com a DLL e o motor do Lua Script
  @author mansano@
  @since 30/12/2022
  @version 0.1
  /*/
method connect(cDLL) class TLuaExec
	local cConnLua, cBuf := ""
	// Abre conexao com a DLL
	::nHandle := ExecInDLLOpen(cDLL)
	::lConnected := (::nHandle > 0)

	// Abre conexao com o Lua, embedado na SO/DLL
	if ::lConnected
		cConnLua := ExecInDllRun(::nHandle, LUA_OPEN, cBuf)
		::lConnected := (cConnLua == "LUA_CONN_OK")
	endif

return

/*/{Protheus.doc} TLuaExec:close
  Encerra a conexao com o Lua e a DLL
  @author mansano@
  @since 30/12/2022
  @version 0.1
  /*/
method close() class TLuaExec
	local cBuf := ""
	cRet := ExecInDLLRun(::nHandle, LUA_CLOSE, cBuf)
	ExecInDllClose(::nHandle)
return cRet

/*/{Protheus.doc} TLuaExec:setVar
  Define nome/valor da variavel Lua
  *Tipos aceitos Caracter / Numerico / Logico
  @author mansano@
  @since 30/12/2022
  @version 0.1
  /*/
method setVar(cVar, xValue) class TLuaExec

	if valtype(xValue) == "C"
		::execute(cVar + " = '" +allTrim(xValue)+ "'")
		return
	endif

	if valtype(xValue) == "N"
		::execute(cVar + " = " + cValToChar(xValue))
		return
	endif

	if valtype(xValue) == "L"
		::execute(cVar + " = " + iif(xValue, "true", "false"))
		return
	endif

return

/*/{Protheus.doc} TLuaExec:getVar
  Recupera o valor da variavel Lua
  *Tipos aceitos Caracter / Numerico / Logico
  @author mansano@
  @since 30/12/2022
  @version 0.1
  /*/
method getVar(cVar) class TLuaExec
	local cLuaType, xTmp
	cLuaType := ::execute("return type(" +cVar+ ")")

	if cLuaType == "string"
		return ::execute("return " + cVar)
	endif

	if cLuaType == "number"
		xTmp := ::execute("return " + cVar)
		xTmp := strTran(xTmp, ",", ".")
		return val(xTmp)
	endif

	if cLuaType == "boolean"
		// Neste ponto foi necessario usar um ternario em Lua para retornar o valor corretamente
		xTmp := ::execute("return not " +cVar+ " and 'FALSE' or 'TRUE'")
		return iif(xTmp=="TRUE", .T., .F.)
	endif

return "" // Retorna vazio caso nao encontre a variavel

/*/{Protheus.doc} TLuaExec:execute
  Executa o trecho Lua, caso seja superior a 512K
  ele sera salvo em arquivo e executado a partir dele

  *Importante:
  O retorno do metodo :execute() esta limitado a 255 bytes
  na camada C/Ansi, para otimizar o trafego de buffers

  @author mansano@
  @since 30/12/2022
  @version 0.1
  /*/
method execute(cCommand) class TLuaExec
	local cFile, xRet := ""
	local nLenComm := len(cCommand)

	// <=255b.: Utiliza ExecInDllRun
	// <=512K.: Utiliza ExeDllRun2
	// +512K..: Executa trecho a partir de arquivo
	if nLenComm <= 255
		xRet := ExecInDllRun(::nHandle, LUA_EXECSTR, cCommand)

	elseif nLenComm > 255 .and. nLenComm <= MAX_BUFFER_DLL
		ExeDllRun2(::nHandle, LUA_EXECSTR, @cCommand)
		xRet := cCommand

	else
		cFile := _getTmpPath(.T.) + "luasrc"+cValtochar(randomize(1, 32766))+".lua"
		::saveSrc(iif(GetRemoteType()==2, 'l:', "")+cFile, cCommand)
		xRet := ExecInDllRun(::nHandle, LUA_EXECFILE, cFile)
	endif

return xRet

/*/{Protheus.doc} TLuaExec:execFile
  Executa arquivo .lua ou .luajit
  @author mansano@
  @since 30/12/2022
  @version 0.1
  /*/
method execFile(cFile) class TLuaExec
	local cFile, xRet := ""
	xRet := ExecInDllRun(::nHandle, LUA_EXECFILE, strtran(cFile, "l:", ""))
return xRet

/*/{Protheus.doc} TLuaExec:saveSrc
  Salva trecho de codigo fonte em arquivo
  @author mansano@
  @since 30/12/2022
  @version 0.1
  /*/
method saveSrc(cFile, cScr) class TLuaExec
	local hFile
	hFile := fcreate(cFile)

	if hFile == -1
		msgStop('TLuaExe:saveSrc() - Error: ' + cValToChar(ferror()))
		__Quit()
	else
		fSeek(hFile, 0, FS_END)
		fWrite(hFile, cScr, len(cScr))
		fClose(hFile)
	endif

return

/*/{Protheus.doc} _getTmpPath
  Retorna o diretorio temporario:
  1-Respeitando o Sistema Operacional
  2-A necessidade de NAO retornar l: em Linux
    quando o Temp Dir for usado no Lua Script
  @author mansano@
  @since 30/12/2022
  /*/
static function _getTmpPath(lLua)
	local cRet := strtran(getTempPath(), "\", "/")
	local isWindows := getRemoteType() == 1
	default lLua := .F.

	// Se lLua = .T. e Linux: remove l:
	if !isWindows .and. !lLua
		cRet := "l:" + cRet
	endif

return cRet

/*/{Protheus.doc} u_luaIDE
  IDE Simples para execucao de trechos Lua Script para testes
  @author mansano@
  @since 30/12/2022
  /*/
function u_luaIDE()
	local oDlg, luaExec, oLuaSrc, oLuaConout, oFont, oControls
	local oControlsTop, cCSSPanel, oSplitter, cDLL
	local cLuaSrc := ""
	local cLuaConout := ""
	local cbSrc, btnRun, srcItems
	local clientDir := getClientDir()
	local isWindows := getRemoteType() == 1

	// [TODO: A GetClientDir() nao retorna l: quando executada no WebAgent em Linux]
	cDLL := clientDir + "luacall." + iif(isWindows, "dll", "so")
	luaExec := TLuaExec():connect(cDLL)

	if !luaExec:lConnected
		_prt("Erro na carga da DLL/SO...")
		return
	else
		_prt("Sucesso na carga da DLL/SO")
	endif

	DEFINE DIALOG oDlg TITLE "Lua Simple IDE" FROM 0, 0 TO 700, 1100 PIXEL

	oSplitter := tSplitter():New( 01, 01, oDlg, 260, 184, 1 )
	oSplitter:Align := CONTROL_ALIGN_ALLCLIENT
	oSplitter:setCSS("TSplitter::handle:vertical{";
		+"background-color: #6272a4;";
		+"height: 5px;}")

	// Editor do Fonte
	oFont := TFont():New('Courier new',,-16,.T.)
	oLuaSrc := TMultiGet():new( 01, 01, {|u| if( pCount()>0, cLuaSrc:=u, cLuaSrc ) }, oSplitter, 260, 92, oFont , , , , , .T. )
	oLuaSrc:align := CONTROL_ALIGN_ALLCLIENT
	cCSSPanel :=	"TMultiGet{";
		+"color: #f1eee6;";
		+"font-size: 16px;";
		+"font-family: courier new;";
		+"border: none;";
		+"border-top: 1px solid #6272a4;";
		+"background-color: #282a36;";
		+"selection-background-color: #44475a;";
		+"}"
	oLuaSrc:setCSS(cCSSPanel)

	// Painel de controle
	oControls := tPanel():New(01,01,,oSplitter,,,,,rgb(255,255,255),25,100)
	oControls:Align := CONTROL_ALIGN_BOTTOM

	srcItems := {'Intercambio de variaveis entre Lua e o TLPP',;
		'Utilizando a biblioteca matematica do Lua',;
		'Cria arquivo na estacao local',;
		'Conexao TCP utilizando o LuaSocket (socket.so)'}

	// Painel que contera o combo e o botao de execucao
	oControlsTop := tPanel():New(01,01,,oControls,,,,,,25,20)
	oControlsTop:setCss("TPanel{background-color: #282a36;}")
	oControlsTop:Align := CONTROL_ALIGN_TOP

	// Combo de opcoes de codigo fonte
	cbSrc := TComboBox():New(03,02,{|u|},;
		srcItems,290,20,oControlsTop,,{|| getLuaSrc(cbSrc:nAt, @cLuaSrc), oLuaSrc:refresh() };
		,,,,.T.,,,,,,,,,'')
	cbSrc:setCss("TComboBox{";
		+"color: #f1eee6;";
		+"background-color: #44475a;";
		+"border: 1px solid #6272a4;";
		+"min-height: 26px;";
		+"font-family: courier new;";
		+"font-size: 14pt;";
		+"}")

	btnRun := TButton():New( 03,294,"Executa",oControlsTop,;
		{|| execLuaSrc(@luaExec, @cLuaSrc, @cLuaConout) },60,14,,,.F.,.T.,.F.,,.F.,,,.F. )
	btnRun:setCSS(;
		"TButton{";
		+"color: #f1eee6;";
		+"background-color: #44475a;";
		+"border: 1px solid #6272a4;";
		+"font-family: courier new; font-size: 14pt;";
		+"}";
		+"TButton:hover{";
		+"background-color: #3b3e4f;";
		+"}")

	// Conout em Tela
	oLuaConout := tMultiget():new( 30, 02, {|u| if( pCount()>0, cLuaConout:=u, cLuaConout ) },;
		oControls, 100, 80, /*oFont*/ , , , , , .T. )
	oLuaConout:setCss(cCSSPanel)
	oLuaConout:Align := CONTROL_ALIGN_ALLCLIENT

	// Carrega primeira opcao de codigo fonte
	getLuaSrc(1, @cLuaSrc)

	ACTIVATE DIALOG oDlg CENTERED

	luaExec:close()
return

/*/{Protheus.doc} execLuaSrc
  Executa trecho de codigo Lua a partir da funcao u_luaIDE()
  @author mansano@
  @since 30/12/2022
  /*/
static function execLuaSrc(luaExec, cLuaSrc, cLuaConout)
	cLuaConout := luaExec:execute(cLuaSrc)
return

/*/{Protheus.doc} getLuaSrc
  Retorna o codigo fonte selecionado via ComboBox na funcao u_luaIDE()
  @author mansano@
  @since 30/12/2022
  /*/
static function getLuaSrc(nSrc, cSrc)
	local beginCont, endCont
	cSrc := "" // Limpa buffer

	if nSrc == LUA_SRC_VAR_LUA_TLPP
		beginCont := "BeginContent"
		endCont := "EndContent"
		BeginContent var cSrc
		--[[
		// Este eh um exemplo basico de troca de informacoes
		// entre o Advpl/TLPP e o Lua, execute este codigo
		// atraves do ambiente Protheus/Logix

function u_MyTest()
	local clientDir := getClientDir()
	local isWindows := getRemoteType() == 1
	local luaExec, cRet, cBuf, varTLPP, cDLL

	cDLL := clientDir + "luacall." + iif(isWindows, "dll", "so")
	luaExec := TLuaExec():connect(cDLL)

	// Define variavel Lua via TLPP, para processamento e retorno dos dados
	luaExec:setVar("varTLPP", 0)

	// Trecho de codigo Lua
	%Exp:cValToChar(beginCont)% var cBuf
	for i=1,99 do
		varTLPP = varTLPP + 1.1 -- Altera valor da variavel criada via AdvPL/TLPP
	end
	%Exp:cValToChar(endCont)%

	// Executa trecho de codigo
	cRet := luaExec:execute(cBuf)

	// Recupera valor da variavel
	varTLPP := luaExec:getVar("varTLPP")
	conout("varTLPP", "Tipo: " +valType(varTLPP), "Valor: " + cValToChar(varTLPP))

        /*
        Retorno da execucao
        varTLPP
        Tipo: N
        Valor: 108.9
        */

	// Encerra conexao
	luaExec:close()
return
	]]
return "Execute este codigo via AdvPL/TLPP"
	EndContent
endif

if nSrc == LUA_SRC_MATH
	BeginContent var cSrc
	-- Mais exemplos em:
	-- https://www.tutorialspoint.com/lua/lua_math_library.htm

	-- Variavel para retorno dos calculos
	cRet = "Funcoes matematicas do Lua"

	-- Retorna min/max entre dois valores
	min = math.min(111, 222)
	cRet = cRet .. "\nMin: " .. min

	max = math.max(111, 222)
	cRet = cRet .. "\nMax: " .. max

	-- Retorna o ângulo x (dado em graus) em radianos.
	radianVal = math.rad(math.pi / 2)
	cRet = cRet .. "\nRad: " .. radianVal

	-- Valor do pecado de 90 (math.pi / 2) graus
	cRet = cRet .. "\nSin Full: " .. math.sin(radianVal)
	cRet = cRet .. "\nSin %.3f: " .. string.format("%.3f ", math.sin(radianVal))

	-- Valor cos de 90(math.pi / 2) graus
	cRet = cRet .. "\nCos.: " .. string.format("%.3f ", math.cos(radianVal))

	-- Valor tan de 90 (math.pi / 2) graus
	cRet = cRet .. "\nTan.: " .. string.format("%.3f ", math.tan(radianVal))

	-- Valor Cosh de 90(math.pi / 2) graus
	cRet = cRet .. "\nCosh: " .. string.format("%.3f ", math.cosh(radianVal))

	-- Valor Pi em graus
	cRet = cRet .. "\nPi..: " .. math.deg(math.pi)

return(cRet)
	EndContent
endif

if nSrc == LUA_SRC_LOCALFILE
	BeginContent var cSrc
	-- Cria arquivo no diretorio Temp da estacao local
	localFile = io.open('%Exp:_getTmpPath(.T.)%filetmp.ini', 'w')
	localFile:write('[linha 01]\n')
	localFile:write('[linha 02]\n')
	localFile:write('[linha 03]\n')
	localFile:write('[linha 04]\n')
	localFile:close()

	-- Se a execucao chegou neste ponto, houve sucesso na criacao do arquivo
return("Arquivo " .. '%Exp:_getTmpPath(.T.)%filetmp.ini' .. " criado com sucesso")
	EndContent
endif

if nSrc == LUA_SRC_TCPSEND
	BeginContent var cSrc
	-- Lembre-se de iniciar o tcpServer.py, contido neste pacote
	-- A execucao deste exemplo depende dos arquivos socket.lua e socket.so
	-- ambos tambem disponiveis neste pacote

	-- Conexao TCP utilizando o LuaSocket (socket.so)
	socket = require('socket')
	local client = socket.connect('192.168.1.26',8080)

	-- Se conectou corretamente
	delay = 300
	if client then
		-- Envia buffer ao socket server e fecha conexao
		client:send('LuaSocket: Mensagem TCP 01')
		totvsL_sleep(delay)
		client:send('LuaSocket: Mensagem TCP 02')
		totvsL_sleep(delay)
		client:send('LuaSocket: Mensagem TCP 03')
		totvsL_sleep(delay)
		client:close()
	else
		return("Conexao TCP falhou")
	end

	-- Se a execucao chegou neste ponto, houve sucesso no envio da msg TCP
return("Mensagem TCP enviada com sucesso")
	EndContent
endif

return

/*/{Protheus.doc} u_luaTest
  Teste de performance entre AdvPL/TLPP e Lua
  @author mansano@
  @since 30/12/2022
  /*/
function u_luaTest()
	local clientDir := getClientDir()
	local isWindows := getRemoteType() == 1
	local rnd := cValtochar(randomize(1, 32766))
	local i, cDll, nHandle, cBuf, cRet
	local luaExec, hFileLoop, tIni, tEnd, varINI, testAdvpl, testLua
	local tmpPath, tmpFile, nCount
	local nLimitFor := 100000  // Limite de loopings para teste do FOR
	local nLimitMail := 1000   // Limite de registros para Mala Direta

	_prt("-----------------------------------------------------------------", .T.)
	_prt("["+cValToChar(nLimitFor)+"] Comparativo somando variavel e IO em arquivo")
	_prt("-----------------------------------------------------------------")

	cDLL := clientDir + "luacall." + iif(isWindows, "dll", "so")
	luaExec := TLuaExec():connect(cDLL)

	if !luaExec:lConnected
		_prt("Erro na carga da DLL/SO...")
		return
	endif

	// --------------------------
	// Executa FOR em AdvPL/TLPP
	// --------------------------
	tIni := seconds()

	hFileLoop := fcreate(_getTmpPath(.F.) + 'fileloopAdvPL'+rnd+'.txt')
	varINI := 0
	for i := 1 to nLimitFor
		varINI++
		fWrite(hFileLoop, "0", 1)
	end
	fClose(nHandle)

	tEnd := seconds()
	testAdvpl := "FOR TLPP.: " + cValToChar(tEnd-tIni) +" segs"

	// --------------------------
	// Executa FOR em Lua
	// --------------------------
	BeginContent var cBuf
	-- Cria arquivo para testar injecao via IO
	fileLoop = io.open('%Exp:_getTmpPath(.T.)%fileloopLua%Exp:rnd%.txt', 'w')

	varINI = 0
	for i=1,%Exp:cValToChar(nLimitFor)% do
		varINI = varINI + 1
		fileLoop:write('0')
	end
	fileLoop:close()
return varINI
	EndContent

	tIni := seconds()
	cRet := luaExec:execute(cBuf)
	tEnd := seconds()
	testLua := ("FOR Lua..: " + cValToChar(tEnd-tIni) +" segs")

	// Mostra tempos
	_prt(testAdvpl)
	_prt(testLua)
	_prt("-----------------------------------------------------------------")

	_prt("-----------------------------------------------------------------", .T.)
	_prt("["+cValToChar(nLimitMail)+"] Comparativo fcreate(TLPP) x io.open(Lua)")
	_prt("-----------------------------------------------------------------")

	// --------------------------
	// Executando via AdvPL/TLPP
	// --------------------------
	//rpcsetenv("99", "01") // [TODO: Comentar caso esteja rodando do ERP]

	DBSelectArea("SA1")
	DBGotop()
	tIni := seconds()
	tmpPath := _getTmpPath(.F.)
	nCount := 0
	while !SA1->(Eof())
		tmpFile := tmpPath+"file_advpl_" + SA1->A1_COD
		nHandle := fcreate(tmpFile)

		cBuf := ;
			SA1->A1_COD + CRLF +;
			SA1->A1_LOJA + CRLF +;
			SA1->A1_NOME + CRLF +;
			SA1->A1_PESSOA + CRLF +;
			SA1->A1_NREDUZ + CRLF +;
			SA1->A1_END + CRLF +;
			SA1->A1_BAIRRO + CRLF +;
			SA1->A1_TIPO + CRLF +;
			SA1->A1_EST + CRLF
		fWrite(nHandle, cBuf, len(cBuf))
		fClose(nHandle)

		nCount++
		if nCount == nLimitMail
			exit
		endif

		DbSkip()
	end
	tEnd := seconds()
	testAdvpl := ("fcreate(AdvPL/TLPP): " + cValToChar(tEnd-tIni) +" segs")

	// --------------------------
	// Executando via Lua
	// --------------------------
	DBGotop()
	tIni := seconds()
	tmpPath := _getTmpPath(.T.)
	nCount := 0
	while !SA1->(Eof())
		tmpFile := tmpPath+"file_lua_" + SA1->A1_COD
		luaExec:execute("f = io.open('"+tmpFile+"', 'w')")

		cBuf := ;
			"'"+ SA1->A1_COD +"\n',"+;
			"'"+ SA1->A1_LOJA +"\n',"+;
			"'"+ SA1->A1_NOME +"\n',"+;
			"'"+ SA1->A1_PESSOA +"\n',"+;
			"'"+ SA1->A1_NREDUZ +"\n',"+;
			"'"+ SA1->A1_END +"\n',"+;
			"'"+ SA1->A1_BAIRRO +"\n',"+;
			"'"+ SA1->A1_TIPO +"\n',"+;
			"'"+ SA1->A1_EST +"\n'"

		luaExec:execute("f:write(" +cBuf+ ")")
		luaExec:execute("f:close()")

		nCount++
		if nCount == nLimitMail
			exit
		endif

		DbSkip()
	end
	tEnd := seconds()
	testLua   := ("io.open(Lua).......: " + cValToChar(tEnd-tIni) +" segs")

	// Mostra tempos
	_prt(testAdvpl)
	_prt(testLua)
	_prt("-----------------------------------------------------------------")

return

/*/{Protheus.doc} _prt
  Conout padronizado
  @author mansano@
  @since 30/12/2022
  /*/
static function _prt(s, breakLine)
	local lib := ""
	local remoteType := getRemoteType(@lib)
	default breakLine := .F.

	if breakLine
		conout("")
	endif

	// Retorna o SO e se esta sendo executado via Webagent
	remoteType := iif(subs(lib, 1, 4)=="HTML", "W", "D") + cValToChar(remoteType)
	conout(" => ["+remoteType+ " - " +procName(1)+ "] "  + allTrim(cValToChar(s)))
return
