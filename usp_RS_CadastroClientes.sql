/*
====================================================================================================================================================================================
WREL005 - Cadastro de clientes 
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
09/01/2025 - WILLIAM
	- Inclusão do hint "OPTION(MAXRECURSION 0)"´, após a chamada da função fSplit() do Municipios para lista de valores do subgrupo, pois tem mais de 100 itens;

08/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;		
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_CadastroClientes]
	@empcod smallint,
	@dataDe datetime,
	@dataAte datetime,
	@codigoCliente varchar(500),
	@nomeCliente varchar(60),
	@codigoVendedor varchar(500),
	@nomeVendedor varchar(60),
	@situacao varchar(50),
	@pessoa varchar(10),
	@classe varchar(10),
	@categoria varchar(500),
	@ramo varchar(500),
	@imprimeBoleto varchar(10),
	@estado varchar(200),
	@municipio varchar(MAX),
	@isencaoIcms varchar(10),
	@nossaFilial varchar(10),
	@somenteVendasVista varchar(10),
	@clienteBloqueado varchar(10),
	@clientesVendedor int,
	@Portador varchar(500)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @DataCad_De datetime, @DataCad_Ate datetime, @CodigosCliente varchar(500), @CLINOM varchar(60), @CodigosVendedor varchar(500),
			@VENNOM varchar(60), @Situacoes varchar(50), @Pessoas varchar(10), @Classes varchar(10), @Categorias varchar(500), @Ramos varchar(500), @SeImpBoleto varchar(10),
			@Estados varchar(200), @Municipios varchar(MAX), @SeIsentoIcms varchar(10), @SeNossaFilial varchar(10), @SeSomenteVendasVista varchar(10), @SeClienteBloq varchar(10),
			@ClientesComVendedor int, @Portadores varchar(500),
			@CmdSQL varchar(MAX);

	-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @DataCad_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @DataCad_Ate = (SELECT ISNULL(@dataAte, GETDATE()));
	SET @CodigosCliente = @codigoCliente;	-- MultiValor
	SET @CLINOM = @nomeCliente;
	SET @CodigosVendedor = @codigoVendedor;	-- MultiValor
	SET @VENNOM = @nomeVendedor;
	SET @Situacoes = @situacao;
	SET @Pessoas = @pessoa;	-- MultiValor
	SET @Classes = @classe;	-- MultiValor
	SET @Categorias = @categoria;	-- MultiValor
	SET @Ramos = @ramo;	-- MultiValor
	SET @SeImpBoleto = @imprimeBoleto;	-- MultiValor
	SET @Estados = @estado;	-- MultiValor
	SET @Municipios = @municipio;	-- MultiValor
	SET @SeIsentoIcms = @isencaoIcms;	-- MultiValor
	SET @SeNossaFilial = @nossaFilial;	-- MultiValor
	SET @SeSomenteVendasVista = @somenteVendasVista;	-- MultiValor
	SET @SeClienteBloq = @somenteVendasVista;	-- MultiValor
	SET @ClientesComVendedor = @clientesVendedor;
	SET @Portadores = @Portador;	-- MultiValor	

	-- Uso da funcao split, para as clausulas IN()
	--- Codigos dos clientes
		If object_id('TempDB.dbo.#CODIGOSCLI') is not null
			DROP TABLE #CODIGOSCLI;
		select elemento as [codcli]
		Into #CODIGOSCLI
		From fSplit(@CodigosCliente, ',')
	--- Codigos dos clientes
		If object_id('TempDB.dbo.#CODIGOSVEN') is not null
			DROP TABLE #CODIGOSVEN;
		select elemento as [codven]
		Into #CODIGOSVEN
		From fSplit(@CodigosVendedor, ',')
	--- Situacoes do cliente
		If object_id('TempDB.dbo.#SITUACOES') is not null
			DROP TABLE #SITUACOES;
		select elemento as [situa]
		Into #SITUACOES
		From fSplit(@Situacoes, ',')
	--- Tipo de pessoas do cliente
		If object_id('TempDB.dbo.#PESSOAS') is not null
			DROP TABLE #PESSOAS;
		select elemento as [pessoa]
		Into #PESSOAS
		From fSplit(@Pessoas, ',')
	--- Classes do cliente
		If object_id('TempDB.dbo.#CLASSES') is not null
			DROP TABLE #CLASSES;
		select elemento as [classe]
		Into #CLASSES
		From fSplit(@Classes, ',')
	--- Classes do cliente
		If object_id('TempDB.dbo.#CATEGORIAS') is not null
			DROP TABLE #CATEGORIAS;
		select elemento as [categ]
		Into #CATEGORIAS
		From fSplit(@Categorias, ',')
	--- Classes do cliente
		If object_id('TempDB.dbo.#RAMOS') is not null
			DROP TABLE #RAMOS;
		select elemento as [ramo]
		Into #RAMOS
		From fSplit(@Ramos, ',')
	--- Se cliente marcado para impressão de boletos
		If object_id('TempDB.dbo.#IMPBOLETO') is not null
			DROP TABLE #IMPBOLETO;
		select elemento as [boleto]
		Into #IMPBOLETO
		From fSplit(@SeImpBoleto, ',')
	--- Estados(UF)
		If object_id('TempDB.dbo.#ESTADOS') is not null
			DROP TABLE #ESTADOS;
		select elemento as [uf]
		Into #ESTADOS
		From fSplit(@Estados, ',')
	--- Municipios
		If object_id('TempDB.dbo.#MUNICIPIOS') is not null
			DROP TABLE #MUNICIPIOS;
		select elemento as [muncod]
		Into #MUNICIPIOS
		From fSplit(@Municipios, ',')
		OPTION(MAXRECURSION 0)
	--- Se cliente isento ICMS
		If object_id('TempDB.dbo.#SEISENTOICMS') is not null
			DROP TABLE #SEISENTOICMS;
		select elemento as [iseicms]
		Into #SEISENTOICMS
		From fSplit(@SeIsentoIcms, ',')
	--- Se cliente nossa filial
		If object_id('TempDB.dbo.#SENOSSAFILIAL') is not null
			DROP TABLE #SENOSSAFILIAL;
		select elemento as [filial]
		Into #SENOSSAFILIAL
		From fSplit(@SeNossaFilial, ',')
	--- Se cliente com vendas somente a vista
		If object_id('TempDB.dbo.#SESOMENTEVENDASVISTA') is not null
			DROP TABLE #SESOMENTEVENDASVISTA;
		select elemento as [soavista]
		Into #SESOMENTEVENDASVISTA
		From fSplit(@SeSomenteVendasVista, ',')
	--- Se cliente bloqueado
		If object_id('TempDB.dbo.#SECLIENTEBLOQ') is not null
			DROP TABLE #SECLIENTEBLOQ;
		select elemento as [clibloq]
		Into #SECLIENTEBLOQ
		From fSplit(@SeClienteBloq, ',')
	--- Portadores do cliente
		If object_id('TempDB.dbo.#PORTADORES') is not null
			DROP TABLE #PORTADORES;
		select elemento as [portador]
		Into #PORTADORES
		From fSplit(@Portadores, ',')
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os codigos dos clientes

	IF @CodigosCliente <> '' 
		SET @CmdSQL = 
			'SELECT 
				CLICOD 
			FROM TBS002 (NOLOCK) 
			WHERE 
			CLICOD IN (SELECT codcli from #CODIGOSCLI)';

	ELSE
		SET @CmdSQL = 
			'SELECT 
				CLICOD 
			FROM TBS002 (NOLOCK)';

	IF object_id('tempdb.dbo.#CodigoCliente') is not null 
		drop table #CodigoCliente;	

	create table #CodigoCliente (clicodigo int)

	INSERT INTO #CodigoCliente
	EXEC(@CmdSQL)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Obtem os codigos dos vendedores

	IF @CodigosVendedor <> '' 
		SET @CmdSQL = 
			'SELECT 
				CLICOD 
			FROM TBS004 (NOLOCK) 
			WHERE 
			VENCOD IN (SELECT codven from #CODIGOSVEN)';

	ELSE
		SET @CmdSQL = 
			'SELECT 
				VENCOD 
			FROM TBS004 (NOLOCK)
			UNION
			SELECT TOP 1
				0 
			FROM TBS004 (NOLOCK)';

	IF object_id('tempdb.dbo.#CodigoVendedor') is not null 
		drop table #CodigoVendedor;

	create table #CodigoVendedor (vencodigo int)

	INSERT INTO #CodigoVendedor
	EXEC(@CmdSQL) 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Obtem detalhes dos vendedores

	IF object_id('tempdb.dbo.#Vendedor') is not null 
		drop table #Vendedor;

	SELECT 
		VENCOD, 
		RTRIM(LTRIM(STR(VENCOD))) + ' ' + rtrim(ltrim(VENNOM)) as VENNOM 
	INTO #Vendedor 
	FROM TBS004 (nolock) 

	where 
	VENCOD IN (select vencodigo from #CodigoVendedor) AND 
	VENNOM LIKE (case when @VENNOM = '' then VENNOM else rtrim(upper(@VENNOM)) end)

	UNION 
	SELECT TOP 1 
		0, 
		'0 SEM VENDEDOR'
	FROM TBS004 (nolock) 
	WHERE 
	0 in (select vencodigo from #CodigoVendedor) AND 
	'SEM VENDEDOR' like(case when @VENNOM = '' then 'SEM VENDEDOR' else rtrim(upper(@VENNOM)) end)

	-- select * from #Vendedor 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem detalhes do cliente filtrando os registros

	IF object_id('tempdb.dbo.#ClientesFiltrados') is not null 	
		drop table #ClientesFiltrados;

	SELECT 
		A.CLICOD, 
		A.RAMCOD, 
		A.RAMEMPCOD, 
		A.CATCOD, 
		A.CATEMPCOD, 
		B.VENCOD, 
		B.VENNOM, 
		CLIPOREMP, 
		CLIPORCOD -- William, 15/09/22
	INTO #ClientesFiltrados
	FROM TBS002 A (nolock)
	INNER JOIN #Vendedor B on A.VENCOD = B.VENCOD 
	WHERE 
	CLIDATCAD BETWEEN @DataCad_De AND @dataAte AND 
	CLICOD IN (SELECT clicodigo FROM #CodigoCliente) AND 
	CLISIT IN (SELECT situa FROM #SITUACOES) AND
	CLITIPPES IN (SELECT pessoa FROM #PESSOAS) AND
	CLICLA IN (SELECT classe FROM #CLASSES) AND
	CATCOD IN (SELECT categ FROM #CATEGORIAS) AND
	RAMCOD IN (SELECT ramo FROM #RAMOS) AND
	CLIIMPBLT IN (SELECT boleto FROM #IMPBOLETO) AND
	UFESIG IN (SELECT uf FROM #ESTADOS) AND
	MUNCOD IN (SELECT muncod FROM #MUNICIPIOS) AND
	CLIISEICMS IN (SELECT iseicms FROM #SEISENTOICMS) AND
	CLIFIL IN (SELECT filial FROM #SENOSSAFILIAL) AND
	CLIBLQTRN IN (SELECT soavista FROM #SESOMENTEVENDASVISTA) AND
	CLIBLQ IN (SELECT clibloq FROM #SECLIENTEBLOQ) AND	
	CLIPORCOD IN (SELECT portador FROM #PORTADORES) AND
	CLINOM LIKE(case when @CLINOM = '' then CLINOM else @CLINOM end) AND 
	A.VENCOD = case when @ClientesComVendedor = 0 then 0 else A.VENCOD end
	
	-- select * from #ClientesFiltrados
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	if object_id('tempdb.dbo.#Clientes') is not null 
		drop table #Clientes;

	SELECT 
	RTRIM(LTRIM(CONVERT(CHAR (10) ,CLIDATCAD,103))) AS 'DATA DE CADASTRO',
	B.CLITIPPES  AS PESSOA,
	RTRIM(LTRIM(B.CLICGC)) AS CNPJ,
	RTRIM(LTRIM(B.CLICPF)) AS CPF,
	RTRIM(LTRIM(CLISIT)) AS SITUACAO,
	A.CLICOD AS CLIENTE,
	RTRIM(LTRIM(CLINOM)) AS 'RAZAO SOCIAL',
	RTRIM(LTRIM(CLINOMFAN)) AS 'FANTASIA',
	'FATURAMENTO' AS ENDER,
	isnull(RTRIM(LTRIM(B.CLIEND)),'') + ' , '+ RTRIM(LTRIM(B.CLINUM)) + ' , '+ ISNULL(RTRIM(LTRIM(B.CLIBAI)),'') AS 'CLIEND',
	RTRIM(LTRIM(B.CLICEP)) AS 'CEP',
	ISNULL(RTRIM(LTRIM(C.MUNNOM)),'') + ' , '+ ISNULL(RTRIM(LTRIM(C.UFESIG)),'')  AS 'CLIMUN',
	RTRIM(LTRIM(CLICONTAT)) AS CONTATO	,
	RTRIM(LTRIM(CLITEL)) AS CLITEL,
	RTRIM(LTRIM(CLIRAM1)) AS RAM1,
	RTRIM(LTRIM(CLITEL2)) AS CLITEL2,
	RTRIM(LTRIM(CLIRAM2)) AS RAM2,
	RTRIM(LTRIM(CLITEL3)) AS CLITEL3,
	RTRIM(LTRIM(CLIRAM3)) AS RAM3,
	RTRIM(LTRIM(CLIEMAIL)) AS EMAIL,

	RTRIM(LTRIM(ISNULL(B.VENCOD,0))) AS 'COD VEN.' ,
	RTRIM(LTRIM(ISNULL(A.VENNOM,'0 SEM VENDEDOR'))) AS 'NOME VEN.',
	CLIBLQ, 
	CLIBLQTRN,
	CLICLA,
	CLIFIL,
	RTRIM(LTRIM(STR(ISNULL(F.CATCOD,0)))) + ' - ' + ISNULL(RTRIM(LTRIM(F.CATDES)),'') AS CATEGORIA,
	RTRIM(LTRIM(STR(ISNULL(G.RAMCOD,0)))) + ' - ' + ISNULL(RTRIM(LTRIM(G.RAMDES)),'') AS RAMO,
	RTRIM(LTRIM(STR(ISNULL(H.PORCOD,0)))) + ' - ' + ISNULL(RTRIM(LTRIM(H.PORNOM)),'') AS PORTADOR	-- William, 15/09/22

	into #Clientes		
	FROM #ClientesFiltrados A 
	INNER JOIN TBS002 B (NOLOCK) ON A.CLICOD = B.CLICOD
	LEFT JOIN TBS003 C (NOLOCK) ON B.MUNCOD = C.MUNCOD
	LEFT JOIN TBS089 F (NOLOCK) ON A.CATEMPCOD = F.CATEMPCOD AND A.CATCOD = F.CATCOD
	LEFT JOIN TBS009 G (NOLOCK) ON A.RAMEMPCOD = G.RAMEMPCOD AND A.RAMCOD = G.RAMCOD
	LEFT JOIN TBS063 H (NOLOCK) ON A.CLIPOREMP = H.POREMPCOD AND A.CLIPORCOD = H.PORCOD				-- William, 15/09/22
						
	WHERE  
	A.CLICOD IN (select CLICOD FROM #ClientesFiltrados)
			
	UNION 
			
	SELECT 
	RTRIM(LTRIM(CONVERT(CHAR (10) ,CLIDATCAD,103))) AS 'DATA DE CADASTRO',
	B.CLIENDTIPPES  AS PESSOA,
	RTRIM(LTRIM(B.CLIENDCGC)) AS CNPJ,
	RTRIM(LTRIM(B.CLIENDCPF)) AS CPF,
	RTRIM(LTRIM(CLISIT)) AS SITUACAO,
	A.CLICOD AS CLIENTE,
	RTRIM(LTRIM(CLINOM)) AS 'RAZAO SOCIAL',
	RTRIM(LTRIM(CLINOMFAN)) AS 'FANTASIA',
	'ENTREGA ' + RTRIM(ltrim(B.CLIENDCOD)) AS ENDER,
	isnull(RTRIM(LTRIM(B.CLILOG)),'') + ' , '+ RTRIM(LTRIM(B.CLIENDNUM))+ ' , '+ RTRIM(LTRIM(B.CLIENDCPL)) + ' , '+ ISNULL(RTRIM(LTRIM(B.CLIENDBAI)),'')  AS 'CLIEND',
	RTRIM(LTRIM(B.CLIENDCEP)) AS 'CEP',
	ISNULL(RTRIM(LTRIM(C.MUNNOM)),'') + ' , '+ ISNULL(RTRIM(LTRIM(C.UFESIG)),'')  AS 'CLIMUN',
	RTRIM(LTRIM(CLICONTAT)) AS CONTATO	,
	RTRIM(LTRIM(CLITEL)) AS CLITEL,
	RTRIM(LTRIM(CLIRAM1)) AS RAM1,
	RTRIM(LTRIM(CLITEL2)) AS CLITEL2,
	RTRIM(LTRIM(CLIRAM2)) AS RAM2,
	RTRIM(LTRIM(CLITEL3)) AS CLITEL3,
	RTRIM(LTRIM(CLIRAM3)) AS RAM3,
	RTRIM(LTRIM(CLIEMAIL)) AS EMAIL,
	RTRIM(LTRIM(ISNULL(A.VENCOD,0))) AS 'COD VEN.' ,
	RTRIM(LTRIM(ISNULL(A.VENNOM,'0 SEM VENDEDOR'))) AS 'NOME VEN.',
	CLIBLQ, 
	CLIBLQTRN,
	CLICLA,
	CLIFIL,
	RTRIM(LTRIM(STR(ISNULL(F.CATCOD,0)))) + ' - ' + ISNULL(RTRIM(LTRIM(F.CATDES)),'') AS CATEGORIA,
	RTRIM(LTRIM(STR(ISNULL(G.RAMCOD,0)))) + ' - ' + ISNULL(RTRIM(LTRIM(G.RAMDES)),'') AS RAMO,
	RTRIM(LTRIM(STR(ISNULL(H.PORCOD,0)))) + ' - ' + ISNULL(RTRIM(LTRIM(H.PORNOM)),'') AS PORTADOR	-- William, 15/09/22

	FROM #ClientesFiltrados A 
	INNER JOIN TBS0021 B (NOLOCK) ON A.CLICOD = B.CLICOD
	INNER JOIN TBS002 D (NOLOCK) ON A.CLICOD = D.CLICOD
	LEFT JOIN TBS003 C (NOLOCK) ON B.CLIENDMUNCOD = C.MUNCOD
	LEFT JOIN TBS089 F (NOLOCK) ON A.CATEMPCOD = F.CATEMPCOD AND A.CATCOD = F.CATCOD
	LEFT JOIN TBS009 G (NOLOCK) ON A.RAMEMPCOD = G.RAMEMPCOD AND A.RAMCOD = G.RAMCOD
	LEFT JOIN TBS063 H (NOLOCK) ON A.CLIPOREMP = H.POREMPCOD AND A.CLIPORCOD = H.PORCOD				-- William, 15/09/22
						
	WHERE  
	A.CLICOD IN (select CLICOD FROM #ClientesFiltrados) AND 
	B.CLIENDTIP = 'E'
			
	UNION

	SELECT 
	RTRIM(LTRIM(CONVERT(CHAR (10) ,CLIDATCAD,103))) AS 'DATA DE CADASTRO',
	B.CLIENDTIPPES  AS PESSOA,
	RTRIM(LTRIM(B.CLIENDCGC)) AS CNPJ,
	RTRIM(LTRIM(B.CLIENDCPF)) AS CPF,
	RTRIM(LTRIM(CLISIT)) AS SITUACAO,
	A.CLICOD AS CLIENTE,
	RTRIM(LTRIM(CLINOM)) AS 'RAZAO SOCIAL',
	RTRIM(LTRIM(CLINOMFAN)) AS 'FANTASIA',
	'COBRANCA ' + RTRIM(ltrim(B.CLIENDCOD)) AS ENDER,
	isnull(RTRIM(LTRIM(B.CLILOG)),'') + ' , '+ RTRIM(LTRIM(B.CLIENDNUM))+ ' , '+ RTRIM(LTRIM(B.CLIENDCPL)) + ' , '+ ISNULL(RTRIM(LTRIM(B.CLIENDBAI)),'')  AS 'CLIEND',
	RTRIM(LTRIM(B.CLIENDCEP)) AS 'CEP',
	ISNULL(RTRIM(LTRIM(C.MUNNOM)),'') + ' , '+ ISNULL(RTRIM(LTRIM(C.UFESIG)),'')  AS 'CLIMUN',
	RTRIM(LTRIM(CLICONTAT)) AS CONTATO	,
	RTRIM(LTRIM(CLITEL)) AS CLITEL,
	RTRIM(LTRIM(CLIRAM1)) AS RAM1,
	RTRIM(LTRIM(CLITEL2)) AS CLITEL2,
	RTRIM(LTRIM(CLIRAM2)) AS RAM2,
	RTRIM(LTRIM(CLITEL3)) AS CLITEL3,
	RTRIM(LTRIM(CLIRAM3)) AS RAM3,
	RTRIM(LTRIM(CLIEMAIL)) AS EMAIL,
	RTRIM(LTRIM(ISNULL(A.VENCOD,0))) AS 'COD VEN.' ,
	RTRIM(LTRIM(ISNULL(A.VENNOM,'0 SEM VENDEDOR'))) AS 'NOME VEN.',
	CLIBLQ, 
	CLIBLQTRN,
	CLICLA,
	CLIFIL,
	RTRIM(LTRIM(STR(ISNULL(F.CATCOD,0)))) + ' - ' + ISNULL(RTRIM(LTRIM(F.CATDES)),'') AS CATEGORIA,
	RTRIM(LTRIM(STR(ISNULL(G.RAMCOD,0)))) + ' - ' + ISNULL(RTRIM(LTRIM(G.RAMDES)),'') AS RAMO,
	RTRIM(LTRIM(STR(ISNULL(H.PORCOD,0)))) + ' - ' + ISNULL(RTRIM(LTRIM(H.PORNOM)),'') AS PORTADOR	-- William, 15/09/22

	FROM #ClientesFiltrados A 
	INNER JOIN TBS0021 B (NOLOCK) ON A.CLICOD = B.CLICOD
	INNER JOIN TBS002 D (NOLOCK) ON A.CLICOD = D.CLICOD
	LEFT JOIN TBS003 C (NOLOCK) ON B.CLIENDMUNCOD = C.MUNCOD
	LEFT JOIN TBS089 F (NOLOCK) ON A.CATEMPCOD = F.CATEMPCOD AND A.CATCOD = F.CATCOD
	LEFT JOIN TBS009 G (NOLOCK) ON A.RAMEMPCOD = G.RAMEMPCOD AND A.RAMCOD = G.RAMCOD
	LEFT JOIN TBS063 H (NOLOCK) ON A.CLIPOREMP = H.POREMPCOD AND A.CLIPORCOD = H.PORCOD				-- William, 15/09/22
			
	WHERE  
	A.CLICOD IN (select CLICOD FROM #ClientesFiltrados) AND
	B.CLIENDTIP = 'C'

	select * from #Clientes
END