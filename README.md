# **LuaCall - Integração AdvPL/TLPP x Lua Script**

> [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)<br>Esta é uma iniciativa open source, sob **Licença MIT**, e como tal, é disponibilizada **sem qualquer garantia, expressa ou implícita**, não havendo restrições sobre usar, copiar, modificar, fundir, publicar, distribuir, sublicenciar e/ou vender cópias de seu conteúdo.
>
> Ajustes e melhorias serão mantidos sob o **modelo colaborativo**, podendo, você como desenvolvedor, estender as características deste pacote de acordo com sua necessidade.

## **Ideia inicial**

O LuaCall possibilita a integração entre o **AdvPL/TLPP e o Lua Script**, através de um conjunto de bibliotecas dinâmicas (**DLLs/SOs**) utilizadas pelo SmartClient, tanto na versão [Desktop](https://tdn.totvs.com/display/tec/SmartClient) quanto na versão HTML (WebApp / [WebAgent](https://tdn.totvs.com/display/tec/2.+WebApp+-+WebAgent)).

> 🚨 **Importante:**<br>Por questões de segurança, a execução do código Lua ocorre **exclusivamente na estação de trabalho**, não sendo possivel acessar arquivos do AppServer através da integração.

### **Porque o Lua Script?**

* **Open Source**, com licença MIT, a mais permissiva existente.
* Está entre as linguagens script mais **rápidas** atualmente.
* Largamente usada em jogos, trazendo **melhorias contínuas** ao seu código.
* Possui um **garbage collector** nativo e eficiente.
* Tem um tamanho médio de apenas **350K**.
* E um mecanismo que permite **embutir seu motor** em linguagens como C, C++, C#, Java, etc.

### **Isso o torna ideal para, rotinas de:**

* Configurações.
* Automações (scripting).
* Prototipagem rápida.

> Para conhecer mais sobre o Lua acesse:  https://www.lua.org/portugues.html

> Para acessar o playground do Lua acesse: https://www.lua.org/cgi-bin/demo

## **Arquivos necessários para uso do exemplo**

As bibliotecas necessárias para uso do exemplo **lua_execindll.prw** estão no diretório **bin/** do pacote, utilize de acordo com seu sistema operacional.

> O desenvolvimento deste pacote focou o **Linux** e o **Windows**, caso precise utilizar a integração no **macOS**, será necessário compilar os pacotes para este sistema operacional, as instruções de compilação para Linux podem ser um ponto de partida para este processo.

```
bin/
├── linux
│   ├── liblua54.so
│   ├── luacall.so
│   ├── socket.so
│   └── socket.lua
└── windows
    ├── lua54.dll
    ├── luacall.dll
    ├── socket.dll
    └── socket.lua
```

> Para execução dos exemplos, as bibliotecas devem estar na **pasta do SmartClient**, pois sua localização é obtida através da função **`getClientDir()`**, você pode alterar este caminho de acordo com sua necessidade, **mas recomendo testes**, para garantir que todas a **dependências do próprio Lua** estejam "resolvidas" em relação aos módulos externos que venha à utilizar, como o LuaSocket, por exemplo.

```js
local clientDir := getClientDir()
local isWindows := getRemoteType() == 1
cDLL := clientDir + "luacall." + iif(isWindows, "dll", "so")
```

## **1. Exemplo AdvPL/TLPP (lua_execindll.prw)**

O código fonte **lua_execindll.prw** está no diretório **TLPP/** do pacote, contendo um conjunto de exemplos para uso da integração.

```
TLPP/
└── lua_execindll.prw
```

**Este exemplo contém:**

* **Classe TLuaExec**
    * Facilitador para uso da integração com as bibliotecas.
* **User Function luaIDE**
    * IDE muito simples para testes de execução dos trechos Lua Script.
* **User Function luaTest**
    * Comparativo de performance entre o AdvPL/TLPP e o Lua.

## **1a. A Classe TLuaExec**

A classe **TLuaExec** é um facilitador para uso da integração AdvPL/TLPP x Lua.

> 🚨 **Importante:**<br>O retorno do metodo **`:execute()`** esta **limitado a 255 bytes** para otimizar o tráfego de buffers.

```js
local clientDir := getClientDir()
local isWindows := getRemoteType() == 1
local luaExec, cDll, cBuf, cRet

// Instancia a classe, apontando para o arquivo luacall.so/dll
cDLL := clientDir + "luacall." + iif(isWindows, "dll", "so")
luaExec := TLuaExec():connect(cDLL)

// A propriedade lConnected retornara .T. 
// caso o Lua Script seja carregado corretamente
if !luaExec:lConnected
  conout("Erro na carga da DLL/SO...")
  return
else
  conout("Sucesso na carga da DLL/SO")
endif	

// Metodo setVar() cria uma variavel Lua atraves do AdvPL/TLPP,
// essa variavel sera utilizada na soma abaixo em Lua
// e seu valor recuperado na sequencia atraves da getVar()
// 
// Parametros:
// cNameVar.: Nome da variavel
// xVarValue: Conteudo da Variavel
//            Tipos aceitos: Caracter / Numerico / Logico
luaExec:setVar('var3', 42)

// Trecho de codigo Lua
BeginContent var cBuf
  var1 = 10
  var2 = 20
  var3 = var1 + var2 + var3 -- Atualiza var3, criada via AdvPL/TLPP
  return(var3) 
EndContent

// Executa o Trecho de codigo Lua
// e recupera o valor atraves do "return(var3)"
//
// Importante:
// Retorno do metodo :execute() limitado a 255 bytes
// para otimizar o trafego de buffers
// 
// Sugestao: 
// Caso precise retornar mais informacoes, estude salva-las
// em arquivo via C/C++, e acessa-las na sequencia via AdvPL/TLPP
cRet := luaExec:execute(cBuf)
conout("Retorno do trecho Lua: " + cRet) // => Retorno do trecho Lua: 72

// Recupera valor da variavel Lua
//
// Importante:
// A variavel pode ter sido criada tanto 
// via AdvPL/TLPP quanto via Lua
//
// Parametro:
// cNameVar.: Nome da variavel
// Retorno..: Conteudo da Variavel
//            Tipos retornados: Caracter / Numerico / Logico
cRet := luaExec:getVar("var3")
conout("Retorno getVar('var3'): " + cValToChar(cRet)) // => Retorno getVar('var3'): 72

// O metodo execFile() interpreta arquivos Lua 
// e tambem arquivos Lua compilados com o LUAC
// 
// Mais informacoes acesse:
// https://www.lua.org/manual/5.1/luac.html
cRet := luaExec:execFile("/home/mansano/Downloads/lua_shared/test.lua")
conout(cRet)

cRet := luaExec:execFile("/home/mansano/Downloads/lua_shared/test.jit")
conout(cRet)

// Encerra a conexao com o Lua Script
luaExec:close()
```

## **1b. luaIDE**

A **User Function luaIDE** permite que você execute trechos Lua Script de maneira simples, para testar suas implementações.

A combo do luaIDE traz 4 exemplos para que você possa começar a conhecer a linguagem:

* Intercâmbio de variáveis entre Lua e o TLPP
    * Este trecho esta em **AdvPL/TLPP**, explicando como criar, processar e recuperar variaveis Lua via AdvPL/TLPP. 
* Utilizando a biblioteca matemática do Lua
* Cria arquivo na estação local
* Conexão TCP utilizando o LuaSocket (socket.so)
    * Para executar ente trecho é necessário que o **tcpServer.py** esteja em execução, veja mais na seção **tcpServer**, neste documento.

```
                 ┌──────────────────────────────────────────────────────────────┐
                 │ Lua Simple IDE                                               │
                 ├──────────────────────────────────────────────────────────────┤
Código fonte   =>│ min = math.min(111, 222)                                     │
Lua Script       │ return(min)                                                  │
                 │                                                              │
Exemplos e       ├────────────────────────────────┬─┬─┬───────────┬─────────────┤
botão Executa  =>│ Combo com exemplos Lua Script  │┅│ │  Executa  │             │
                 ├────────────────────────────────┴─┴─┴───────────┴─────────────┤
Resultado/Erro =>│ 111                                                          │
de execução      │                                                              │
                 └──────────────────────────────────────────────────────────────┘
```
Para que um trecho de código "devolva" um valor utilize o **return** do Lua Script, o retorno esta **limitado à 255 bytes** para otimizar o tráfego de buffers, exemplo:

```lua
var1 = 10
return var1
```

Caso o trecho apresente **erros de execução**, eles também serão exibidos.

> 🚨 **Importante:**<br>
Como explicado inicialmente, a localização das bibliotecas é obtida através da função **`getClientDir()`**, ao executar o exemplo em **Linux**, via **WebApp** (navegador), o diretório corrente não será o diretório retornado pela função getClientDir(): `/opt/web-agent`, inviabilizando a localização dos arquivos **socket.so/dll** e **socket.lua**, apresentando o erro abaixo:

```sh
[string "  -- Lembre-se de iniciar o tcpServer.py, con..."]:6: module 'socket' not found:
	no field package.preload['socket']
	no file '/usr/local/share/lua/5.4/socket.lua'
	no file '/usr/local/share/lua/5.4/socket/init.lua'
	no file './socket.lua'
	no file './socket/init.lua'
```

A solução é executar o exemplo diretamente através do **WebAgent**, via linha de comando, passando o `IP:Porta` do Servidor WebApp e o `caminho para o seu navegador`, siga **exatamente** o exemplo abaixo:

```sh
cd /opt/web-agent/
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:./
./web-agent launch "http://192.168.1.26:8033" --browser="/usr/bin/microsoft-edge"
```
> Mais informações acesse:<br>
https://tdn.totvs.com/display/tec/2.+WebApp+-+WebAgent#id-2.WebAppWebAgent-command_line

## **1c. User Function luaTest**

A **User Function luaTest** fornece um comparativo de tempos de execução entre o AdvPL/TLPP e o Lua Script.

> O Lua tem a **vantagem de ser executado localmente**, enquanto o AdvPL/TLPP são executados no ambiente **Client/Server**, e dependem da comunicação entre essas duas camadas.

Foram comparados:

* `FOR` AdvPL/TLPP e Lua, somando uma variavel e inserindo '0' em um arquivo (IO)
* `FCreate` (AdvPL/TLPP) e o `io.open` (Lua)

> Os tempos de execução **podem variar** de acordo com o sistema operacional e o ambiente em execução, Desktop ou  Web, abaixo um exemplo do comparativo em **Linux**, utilizando o **SmartClient Desktop**.

```
 => [D2 - U_LUATEST] -----------------------------------------------------------------
 => [D2 - U_LUATEST] [100000] Comparativo somando variavel e IO em arquivo
 => [D2 - U_LUATEST] -----------------------------------------------------------------
 => [D2 - U_LUATEST] FOR TLPP.: 5.46 segs
 => [D2 - U_LUATEST] FOR Lua..: 0.012 segs
 => [D2 - U_LUATEST] -----------------------------------------------------------------

 => [D2 - U_LUATEST] -----------------------------------------------------------------
 => [D2 - U_LUATEST] [1000] Comparativo fcreate(TLPP) x io.open(Lua)
 => [D2 - U_LUATEST] -----------------------------------------------------------------
 => [D2 - U_LUATEST] fcreate(AdvPL/TLPP): 5.989 segs
 => [D2 - U_LUATEST] io.open(Lua).......: 1.694 segs
 => [D2 - U_LUATEST] -----------------------------------------------------------------
```


## **tcpServer**

O código fonte **tcpServer.py** está no diretório **tcpServer/** do pacote, contendo um **pequeno TCP Server** escrito em Python para testes da biblioteca LuaSocket (**socket.so/dll**).

```
tcpServer/
└── tcpServer.py
```

Para executá-lo é necessária a **instalação do Python** em sua estação, caso ja tenha instalado, pode executar diretamente da linha de comando:

```powershell
python3 tcpServer.py
```

**Trecho de código Lua enviando as mensagens TCP**

```lua
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
```

**TCP Server recebendo as menagens**

```powershell
Connection from: ('192.168.1.26', 56566)
Send by SocketClient: LuaSocket: Mensagem TCP 01
Send by SocketClient: LuaSocket: Mensagem TCP 02
Send by SocketClient: LuaSocket: Mensagem TCP 03
```

# **Compilando as bibliotecas C**

Para sua comodidade as bibliotecas **luacall e LuaSocket** estão compiladas e disponiveis no diretório **bin/** deste pacote.

```
bin/
├── linux
│   ├── liblua54.so
│   ├── luacall.so
│   ├── socket.so
│   └── socket.lua
└── windows
    ├── lua54.dll
    ├── luacall.dll
    ├── socket.dll
    └── socket.lua
```

Você pode **re-compilar** as bibliotecas a partir de seus códigos fonte.

Compilando o luacall, você pode **criar novas funções** acessíveis via Lua Script, falo mais a respeito no decorrer deste documento.

## **Bibliotecas do Lua Script**

As bibliotecas/includes oficiais da **versão 5.4.4 do Lua** estão disponíveis no diretório **lua/** deste pacote.

```
lua
├── include
│   ├── lauxlib.h
│   ├── luaconf.h
│   ├── lua.h
│   ├── lua.hpp
│   └── lualib.h
├── linux
│   ├── liblua54.a
│   └── liblua54.so
└── windows
    ├── lua54.dll
    └── lua54.lib
```

**Abaixo os links oficiais para download:**

* Linux 64 bits
    * https://sourceforge.net/projects/luabinaries/files/5.4.2/Linux%20Libraries/
* Windows 64 bits
    * https://sourceforge.net/projects/luabinaries/files/5.4.2/Windows%20Libraries/Dynamic/<br>
    **procure pelas bibliotecas Win64**

## **Compilando a biblioteca luacall.so para Linux - Testado com GCC 10.2.1**

A partir da raiz deste pacote

```powershell
cd <raiz do pacote>
cd luacall
# Copie o arquivo <raiz do projeto>/lua/linux/liblua54.so para pasta <raiz do projeto>/luacall
gcc -O3 -fpic -shared -I../lua/include luacall.c liblua54.so -o luacall.so

ls -al *.so
-rwxr-xr-x 1 mansano mansano 16616 jan  7 15:10 luacall.so
```

## **Compilando a biblioteca luacall.dll para Windows - Testado com VS 2022 Community**

Abra o **x64 Native Tools Command Prompt for VS 2022**, será apresentada a linha de comando.

A partir da raiz deste pacote

```powershell
**********************************************************************
** Visual Studio 2022 Developer Command Prompt v17.4.1
** Copyright (c) 2022 Microsoft Corporation
**********************************************************************
[vcvarsall.bat] Environment initialized for: 'x64'

C:\Program Files\Microsoft Visual Studio\2022\Community>

cd <raiz do pacote>
cd luacall

cl /LD /MD ..\lua\windows\lua54.lib Ws2_32.lib luacall.c /Feluacall.dll /I..\lua\include /I"C:\Program Files (x86)\Windows Kits\10\Include\10.0.22000.0\ucrt"

dir *.dll
06/01/2023  23:02            11.264 luacall.dll
```
## **Criando novas funções Lua Script**

Existe um mecanismo simples para implementar **novas funcionalidades** que podem ser publicadas para uso via Lua Script.

A função **`totvsL_sleep()`** do fonte **luacall.c** é um exemplo.

> Mais informações acesse: https://www.lua.org/pil/26.1.html

**Veja o exemplo:**

```c
// Cria a funcao C/C++ que sera publicada
static int totvsL_sleep (lua_State *L) {
	const int delay = luaL_checknumber(L, 1); // 1o argumento da funcao

#ifdef _WIN32
    Sleep(delay);
#else
    usleep(delay*1000);
#endif

    return 1;		
}

// Registra a funcao C/C++ para uso via Lua
lua_pushcfunction(L, totvsL_sleep);
lua_setglobal(L, "totvsL_sleep");	

// Trecho de codigo Lua utilizando a funcao totvsL_sleep nativamente
local client = socket.connect('192.168.1.26',8080)
delay = 300
client:send('LuaSocket: Mensagem TCP 01')
totvsL_sleep(delay)
client:send('LuaSocket: Mensagem TCP 02')
totvsL_sleep(delay)
```

## **LuaSocket (MIT license)**

O LuaSocket é um módulo Lua muito conhecido, responsável pela comunicação TCP/UDP.

O projeto está disponível no diretório **luasocket/** deste pacote.

```
luasocket/
├── CHANGELOG.md
├── src
│   ├── auxiliar.c
│   ├── auxiliar.h
│   ├── buffer.c
│   ├── buffer.h
```

**Abaixo os links oficiais para download:**

* https://luarocks.org/modules/luasocket/luasocket
* https://github.com/lunarmodules/luasocket

## **Compilando o LuaSocket para Linux - Testado com o GCC 10.2.1**

Ao compilar o LuaSocket em Linux, é necessário linkar a referência à biblioteca **liblua54.so**. 

Para tanto:

* Copie o arquivo \<raiz do projeto\>/lua/linux/**liblua54.so** para pasta \<raiz do projeto\>/luasocket/src 
* Edite o arquivo \<raiz do projeto>\/luasocket/src/**makefile** e ajuste a propriedade **LDFLAGS_linux** como no exemplo abaixo:

```powershell
LDFLAGS_linux=-O -shared -fpic liblua54.so -o
```
Agora basta compilar o projeto:
```powershell
cd <raiz do projeto>/luasocket/
make
```

Após a compilação, as bibliotecas estarão disponíveis no diretório \<raiz do projeto>\/luasocket/src/
* socket-3.0.0.so
* mime-1.0.3.so
* serial.so
* unix.so

Para utilizar a biblioteca socket.so que compilou, renomeie o arquivo:
* socket-3.0.0.so => socket.so

>Para utilizar os exemplos deste pacote você só irá precisar do arquivo **socket.so**.<br>
>Para conhecer mais sobre o LuaSocket, seus exemplos e a utilização das demais bibliotecas, acesse: https://github.com/lunarmodules/luasocket

## **Compilando o LuaSocket para Windows - Testado com o VS 2022 Community**

Para compilar o LuaSocket a partir de seus fontes, abra a solution **luasocket.sln**.

> Ao abrir a solution, caso esteja utilizando uma versão do Visual Studio superior à original do projeto, será perguntado se pretende migra-lo para esta versão, confirme, fazendo o update.

É necessário ajustar o arquivo **Lua.props** (*na raiz do projeto*) para respeitar a árvore de diretórios de dependências, você pode se guiar pelo arquivo Lua.props já ajustado na pasta **luasocket/** deste pacote.

**Abaixo um exemplo do ajuste:**

```powershell
<LUAV>54</LUAV>
<LUAPREFIX>..\lua</LUAPREFIX>
<LUALIBNAME>$(LUAPREFIX)\windows\lua$(LUAV.Replace('.', '')).lib</LUALIBNAME>
```

Feitos os ajustes, basta compilar o projeto **socket** e o projeto **mime** (*opcional*) através do VS 2022.

Após a compilação, as bibliotecas estarão disponíveis nos diretórios:
* x64\Release\socket\core.dll
* x64\Release\mime\core.dll

Para utilizar as bibliotecas que compilou, renomeie os arquivos respectivamente para:
* x64\Release\socket\core.dll => socket.dll
* x64\Release\mime\core.dll => mime.dll

>Para utilizar os exemplos deste pacote você só irá precisar do arquivo **socket.dll**<br>
>Para conhecer mais sobre o LuaSocket, seus exemplos e a utilização das demais bibliotecas, acesse: https://github.com/lunarmodules/luasocket

# **Estrutura de diretórios deste pacote**

* **lua/**
    * `include/ `- Includes do Lua.
    * `linux/` - Biblioteca estática do Lua para Linux.
    * `windows/` - Biblioteca dinâmica do Lua para Windows.
* **bin/**
    * `linux/`
        * `liblua54.so` - Biblioteca necessária para execução do Lua Script.
        * `luacall.so` - Biblioteca responsável pela integração AdvPL/TLPP x Lua.
        * `socket.so` - Biblioteca LuaSocket responsável pela comunicação TCP/UDP.
        * `socket.lua` - Arquivo comum entre Linux e Windows, necessário em ambos sistemas operacionais para comunicação TCP/UDP.
    * `windows/`
        * `lua54.dll` - Biblioteca necessária para execução do Lua Script.
        * `luacall.dll` - Biblioteca responsável pela integração AdvPL/TLPP x Lua.
        * `socket.dll` - Biblioteca LuaSocket responsável pela comunicação TCP/UDP.
        * `socket.lua` - Arquivo comum entre Linux e Windows, necessário em ambos sistemas operacionais para comunicação TCP/UDP.
* **luacall/**
    * `lucall.c` - Fonte C Ansi para compilação da SO/DLL no padrao Protheus/Logix para ser consumida através da função **ExecInDllOpen()**.<br>
* **luasocket/**
    * Essa pasta contém o código fonte do LuaSocket (MIT license), mais informações acesse:<br>
    https://github.com/lunarmodules/luasocket
* **tcpServer/**
    * `tcpServer.py` - Pequeno TCP Server para testes da biblioteca LuaSocket (**socket.so/dll**).
* **TLPP/**
    * `lua_execindll.prw` - Classe TLuaExec e exemplos **AdvPL/TLPP** para consumo da integração com o Lua Script.
