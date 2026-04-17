/*
====================================================================================================================================================================================
WREL125 - Solicitacao pagamentos fornecedores
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
18/01/2025 - WILLIAM
	- Uso de consultas dinamicas, juntamente com a SP "sp_executesql";
	- Inclusão de filtro pela empresa da tabela, usando a SP "usp_GetCodigoEmpresaTabela" irá atender empresas como ex.: MRE Ferramentas;
17/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parametros de entrada da SP;	
	- Uso da SP "usp_FornecedoresGrupo";  
	- Uso da SP "usp_GetCodigosFornecedores"; 
************************************************************************************************************************************************************************************
*/
--CREATE PROCEDURE [dbo].[usp_RS_SolicitacaoPagamentosFornecedores]
ALTER PROCEDURE [dbo].[usp_RS_SolicitacaoPagamentosFornecedores]
	@empcod smallint,
	@datCadDe datetime,
	@datCadAte datetime,
	@codComprador varchar(5000),
	@nomComprador varchar(60),
	@codFornecedor int,
	@nomFornecedor varchar(60),
	@numPedCom varchar(500),
	@conGrupo char(1)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS006 smallint, @empresaTBS045 smallint, @empresaTBS046 smallint,
			@datCad_De datetime, @datCad_Ate datetime, @CodigosComprador varchar(5000), @COMNOM varchar(60), @FORCOD int, @FORNOM varchar(60), @ForGRUPO char(1), @Pedidos varchar(500),
			@cmdSQL nvarchar(MAX), @ParmDef nvarchar(500), @nomeEmpresa varchar(40);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @datCad_De = (SELECT ISNULL(@datCadDe, '17530101'));
	SET @datCad_Ate = (SELECT ISNULL(@datCadAte, GETDATE()));
	SET @CodigosComprador = @codComprador;
	SET @COMNOM = RTRIM(LTRIM(UPPER(@nomComprador)));
	SET @FORCOD = @codFornecedor;
	SET @FORNOM = RTRIM(LTRIM(UPPER(@nomFornecedor)));
	SET @Pedidos = @numPedCom;
	SET @ForGRUPO = @conGrupo;

-- Uso da função split, para as claúsulas IN()
	-- Codigos de compradores
	IF object_id('tempdb.dbo.#CODIGOSCOMP') IS NOT NULL
		DROP TABLE #CODIGOSCOMP;
	SELECT 
		elemento as valor
	INTO #CODIGOSCOMP FROM fSplit(@CodigosComprador, ',')
	--Numeros dos pedidos
	IF object_id('tempdb.dbo.#PEDIDOS') IS NOT NULL
		DROP TABLE #PEDIDOS;
	SELECT 
		elemento as valor
	INTO #PEDIDOS FROM fSplit(@Pedidos, ',');
	IF @Pedidos = ''
		DELETE #PEDIDOS;

-- Verificar se a tabela é compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS006', @empresaTBS006 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS045', @empresaTBS045 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS046', @empresaTBS046 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem códigos dos compradores

	IF object_id('tempdb.dbo.#COMCOD') IS NOT NULL
		DROP TABLE #COMCOD;	

	CREATE TABLE #COMCOD (COMCOD INT)

	SET @cmdSQL = N'
		INSERT INTO #COMCOD

		SELECT 
			COMCOD 
		FROM TBS046 (NOLOCK) 
		WHERE
		COMEMPCOD = @empresaTBS046'
		+
		IIF(@CodigosComprador = '', '', ' AND COMCOD IN (SELECT valor FROM #CODIGOSCOMP)')
		+
		IIF(@CodigosComprador = '', '', ' UNION SELECT TOP 1 0 FROM TBS046 (NOLOCK) WHERE 0 IN (SELECT valor FROM #CODIGOSCOMP)')
		+
		IIF(@CodigosComprador <> '', '', ' UNION SELECT TOP 1 0 FROM TBS046 (NOLOCK)')

	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'@empresaTBS046 smallint'
	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS046

--	SELECT * FROM #COMCOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento dos compradores

	IF object_id('tempdb.dbo.#Compradores') IS NOT NULL
		DROP TABLE #Compradores;

	SELECT 
		COMCOD,
		LTRIM(RTRIM(STR(COMCOD))) + ' - ' + RTRIM(COMNOM) AS COMNOM
	INTO #Compradores FROM TBS046 

	WHERE
		COMCOD IN (SELECT COMCOD FROM #COMCOD) AND 
		RTRIM(LTRIM(COMNOM)) LIKE (CASE WHEN @COMNOM = '' THEN RTRIM(LTRIM(COMNOM)) ELSE @COMNOM END) 

	UNION
	SELECT TOP 1 
		0,
		'0 - SEM COMPRADOR' AS VENNOM
	FROM TBS046 (NOLOCK)

	WHERE
		0 IN (SELECT COMCOD FROM #COMCOD) AND 
		'SEM COMPRADOR' LIKE (CASE WHEN @COMNOM = '' THEN 'SEM COMPRADOR' ELSE @COMNOM END)

--	 SELECT * FROM  #Compradores
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem codigos dos fornecedores que sao empresas do grupo

	IF object_id('tempdb.dbo.#CodigosFornecedorGrupo') is not null	
		DROP TABLE #CodigosFornecedorGrupo;

	CREATE TABLE #CodigosFornecedorGrupo (codigo int);

	IF @ForGRUPO = 'S'
		INSERT INTO #CodigosFornecedorGrupo
		EXEC usp_FornecedoresGrupo @codigoEmpresa;

	-- Refinamento dos fornecedores, obtendo mais dados da TBS006

	IF object_id('tempdb.dbo.#TBS006GRU') IS NOT NULL
		DROP TABLE #TBS006GRU;

	CREATE TABLE #TBS006GRU (FORCOD INT, FORNOM VARCHAR(60), FORCGC varchar(14), FORCPF varchar(11), FORTIPPES char(1))

	SET @cmdSQL = N'
		INSERT INTO #TBS006GRU

		SELECT 
			FORCOD, 
			RTRIM(FORNOM) AS FORNOM,
			FORCGC,
			FORCPF,
			FORTIPPES
		FROM TBS006 (NOLOCK) 
		WHERE 
			FOREMPCOD = @empresaTBS045
			AND FORCOD IN (SELECT codigo FROM #CodigosFornecedorGrupo)'
			+
			IIF(@FORCOD = 0, '', ' AND FORCOD = @FORCOD')
			+
			IIF(@FORNOM = '', '', 'AND FORNOM LIKE @FORNOM')
	
	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'@empresaTBS045 smallint, @FORCOD int, @FORNOM varchar(60)'
	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS045, @FORCOD, @FORNOM

--	SELECT * FROM #TBS006GRU
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem codigos dos fornecedores que NAO sao empresas do grupo

	IF object_id('tempdb.dbo.#CodigosFornecedor') IS NOT NULL
		DROP TABLE #CodigosFornecedor;

	CREATE TABLE #CodigosFornecedor (codigo int);

	INSERT INTO #CodigosFornecedor
	EXEC usp_GetCodigosFornecedores @codigoEmpresa, @FORCOD, @FORNOM, 'N'; -- nao considera empresas do grupo

--	SELECT * FROM #CodigosFornecedor

	-- Refinamento dos fornecedores, obtendo mais dados da TBS006

	IF object_id('tempdb.dbo.#TBS006') IS NOT NULL
		DROP TABLE #TBS006;

	CREATE TABLE #TBS006 (FORCOD INT, FORNOM VARCHAR(60), FORCGC varchar(14), FORCPF varchar(11), FORTIPPES char(1))

	INSERT INTO #TBS006
	SELECT 
		FORCOD, 
		RTRIM(FORNOM) AS FORNOM,
		FORCGC,
		FORCPF,
		FORTIPPES
	FROM TBS006 (NOLOCK) 

	WHERE 
		FORCOD IN (SELECT codigo FROM #CodigosFornecedor)

--	SELECT * FROM #TBS006
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Faz a uniao das tabelas de fornecedores

	IF object_id('tempdb.dbo.#Fornecedores') IS NOT NULL
		DROP TABLE #Fornecedores;	

	SELECT 
		*
	INTO #Fornecedores FROM #TBS006

	UNION 
	SELECT 
		*
	FROM #TBS006GRU

--	SELECT * FROM #Fornecedores
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os numeros dos pedidos de compras, caso seja filtrado	

	IF object_id('tempdb.dbo.#NUMEROPEDIDO') IS NOT NULL
		DROP TABLE #NUMEROPEDIDO;

	CREATE TABLE #NUMEROPEDIDO (PDCNUM INT)

	SET @cmdSQL = N'
		INSERT INTO #NUMEROPEDIDO
		SELECT 
			PDCNUM 
		FROM TBS045 (NOLOCK) 
		WHERE FOREMPCOD = @empresaTBS045		
		AND PDCDATCAD BETWEEN @datCad_De AND @datCad_Ate		
		AND COMCOD IN (SELECT COMCOD FROM #Compradores)		
		AND FORCOD IN (SELECT FORCOD FROM #Fornecedores)'
		+
		IIF(@Pedidos = '', '', ' AND PDCNUM IN (SELECT valor FROM #PEDIDOS)')

	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'@empresaTBS045 smallint, @datCad_De datetime, @datCad_Ate datetime'
	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS045, @datCad_De, @datCad_Ate

--	SELECT * FROM #NUMEROPEDIDO
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Bancos dos fornecedores filtrados acima 

	IF object_id('tempdb.dbo.#BANCOS') IS NOT NULL
		DROP TABLE #BANCOS;	

	SELECT 
		row_number() over (partition by FORCOD ORDER BY FORCOBDATCAD) as rank,
		*
	INTO #BANCOS FROM TBS0061 (NOLOCK)
	WHERE
		FORCOD IN (SELECT FORCOD FROM #Fornecedores)	

	DELETE #BANCOS 
		WHERE rank > 1

-- Select * from #Bancos
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Unir as tabelas para formar uma tabela final, com preço unitario final de cada item

	IF object_id('tempdb.dbo.#PEDIDOCOMPRAS') IS NOT NULL
		DROP TABLE #PEDIDOCOMPRAS;

	SELECT 
		row_number() over (order by B.PDCNUM) as rank,
		dbo.PrimeiraMaiuscula(C.COMNOM) AS codigoNomeComprador,
		B.PDCNUM AS numeroPedido,
		B.FORCOD AS codigoFornecedor,
		dbo.PrimeiraMaiuscula(D.FORNOM) AS nomeFornecedor,
		PDCDATCAD AS dataCadastro,
		dbo.PDCTOTBRU(B.PDCEMPCOD, B.PDCNUM) AS valorPedido,
		F.FORCOBBANCOD AS codigoBanco,
		FORCOBNUMAGE AS agencia,
		FORCOBNUMCCO AS numeroConta,
		FORTIPPES AS tipoFornecedor,
		case FORTIPPES
			when 'F' then dbo.FormatarCpf(FORCPF)
			when 'J' then dbo.FormatarCnpj(FORCGC)
			else ''
		end as cnpjCpf
	INTO #PEDIDOCOMPRAS FROM TBS045 B (NOLOCK)
		LEFT JOIN #Compradores C ON B.COMCOD = C.COMCOD
		LEFT JOIN #Fornecedores D ON B.FORCOD = D.FORCOD
		LEFT JOIN #BANCOS F On B.FORCOD = F.FORCOD
	WHERE 
		PDCNUM IN (SELECT PDCNUM FROM #NUMEROPEDIDO)

	SELECT * FROM #PEDIDOCOMPRAS
END
GO