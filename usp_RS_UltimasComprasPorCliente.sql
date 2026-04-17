/*
====================================================================================================================================================================================
WREL132 - Ultimas compras por cliente
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
09/02/2026 WILLIAM
	- Conversao do parametro de entrada de varchar para int: @codigoCliente;
22/03/2025 WILLIAM
	- Uso das SPs "usp_Get_DWVendas" e "usp_Get_DWDevolucaoVendas", para obter as informacoes vendas e devolucao;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
08/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;		
====================================================================================================================================================================================
*/
--ALTER PROCEDURE [dbo].[usp_RS_UltimasComprasPorCliente_DEBUG]
ALTER PROCEDURE [dbo].[usp_RS_UltimasComprasPorCliente]
	@empcod smallint,
	@dataDe date,
	@dataAte date,
	@codigoCliente int = 0,
	@nomeCliente varchar(60) = '',
	@codigoVendedor varchar(500) = '',
	@estados varchar(100) = '',
	@clientesSemComCompra int = 2 -- todos: com e sem compras
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @data_De datetime, @data_Ate datetime, @CLICOD int, @CLINOM varchar(60), @VENCOD varchar(500),
			@UFs varchar(100), @OpcaoCompras int, @contabiliza varchar(10), @codigoDevolucao int,
			@empresaTBS002 smallint, @empresaTBS004 smallint;
	
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;

	SET @data_De = (select ISNULL(@dataDe, '17530101'));
	SET @data_Ate = (select ISNULL(@dataAte, GETDATE() - 1));
	SET @CLICOD = @codigoCliente;	-- MultiValor
	SET @CLINOM = @nomeCliente;
	SET @VENCOD = @codigoVendedor;	-- MultiValor
	SET @UFs = @estados;	-- MultiValor
	SET @OpcaoCompras = @clientesSemComCompra;

-- Atribuicoes internas
	-- Desconsiderar vendas para o grupo...
	SET @contabiliza = 'C,L';

	SET @codigoDevolucao = (CONVERT(int, dbo.ufn_Get_Parametro(1330)));	

-- Uso da funcao split, para as claasulas IN()
	-- Estados(UFs)
	IF OBJECT_ID('tempdb.dbo.#MV_ESTADOS') IS NOT NULL
		DROP TABLE #MV_ESTADOS;

		SELECT
			elemento AS [valor]
		INTO #MV_ESTADOS FROM fSplit(@UFs, ',')

-- Verificar se a tabela compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Obtem codigos dos vendedores via SP, incluindo codigo 0(zero)

	IF OBJECT_ID('tempdb.dbo.#CODVEN') IS NOT NULL
		DROP TABLE #CODVEN;

	CREATE TABLE #CODVEN (VENCOD INT)
	
	INSERT INTO #CODVEN
	EXEC usp_Get_CodigosVendedores @codigoEmpresa, @VENCOD, '', 'TRUE';

	-- Refinamento dos vendedores
	IF OBJECT_ID('tempdb.dbo.#VEND') IS NOT NULL 
		DROP TABLE #VEND;

		SELECT
			VENCOD,
			RTRIM(LTRIM(VENNOM)) AS VENNOM
		INTO #VEND FROM TBS004 A (NOLOCK)
		WHERE 
			VENEMPCOD = @empresaTBS004 AND
			VENCOD IN(SELECT VENCOD FROM #CODVEN)
		UNION
		SELECT TOP 1
			0,
			'SEM VENDEDOR' AS VENNOM
		FROM TBS004 (NOLOCK)

		WHERE
			0 IN(SELECT VENCOD FROM #CODVEN)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Obtem codigos dos cliente via SP

	IF OBJECT_ID('tempdb.dbo.#CODCLIENTES') IS NOT NULL
		DROP TABLE #CODCLIENTES;

	CREATE TABLE #CODCLIENTES (CLICOD INT)
	
	INSERT INTO #CODCLIENTES
	EXEC usp_Get_CodigosClientes @codigoEmpresa, '', @CLINOM, 'N';

	-- Refinamento dos clientes
	IF OBJECT_ID('tempdb.dbo.#CLIENTES') IS NOT NULL
		DROP TABLE #CLIENTES;
   
	SELECT 
		VENCOD as codigoVendedor,
		CLICOD as codigoCliente,
		RTRIM(CLINOM) as razaoSocialCliente,
		RTRIM(CLIOBS) as observacao,
		UFESIG as estado
	INTO #CLIENTES FROM TBS002 (NOLOCK)

	WHERE 
		CLIEMPCOD = @empresaTBS002 AND
		CLICOD IN (SELECT CLICOD FROM #CODCLIENTES) AND
		VENCOD IN (SELECT VENCOD FROM #CODVEN) AND 
		UFESIG IN (SELECT valor FROM #MV_ESTADOS)

	ORDER BY 
		CLIEMPCOD,
		CLICOD, 
		CLINOM, 
		VENCOD	

--	select * FROM #CLIENTES;
/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@puf = @UFs,
		@pcodigoCliente = @CLICOD,
		@pnomeCliente = @CLINOM,
		@pcodigoVendedor = @VENCOD,
		@pcontabiliza = @contabiliza

--	select * from ##DWVendas
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para obter informacao da tabela de METAS, e contabilizar as vendas e devolucoes por vendedor;

	;WITH
	compras AS (	
		SELECT
			row_number() OVER(PARTITION BY codigoCliente ORDER BY data DESC) AS rank,
			codigoCliente,
			nomeCliente,
			data,
			codigoVendedor,
			nomeVendedor			
		FROM ##DWVendas

		WHERE 
			codigoCliente > 0	-- Somente clientes com cadastro, vendas de loja contem CPF ou CNPJ, porem nao tem cadastro no sistema;
		GROUP BY 
			codigoCliente,
			nomeCliente,
			data,
			codigoVendedor,
			nomeVendedor
	),		
	-- Obtem somente os clientes com rank = 1, que e a ultima compra
	ultimas_compras AS(
		SELECT
			*
		FROM compras
		WHERE
			rank = 1
	),	
	-- Obtem somente os clientes com rank = 2, que e a penultima compra
	penultimas_compras AS(
		SELECT
			*
		FROM compras
		WHERE
			rank = 2
	),
	-- Agrupa as ultimas e penultimas compras, com base na tabela de clientes #cliente, tendo a possibilidade de nao ter registro de compras conforme o periodo 
	ultimas_compras_ajustadas AS (
	SELECT
		C.codigoVendedor,
		C.codigoCliente,
		C.razaoSocialCliente,
		estado,
		ISNULL(U.data, '17530101') as dataUltimaCompra,
		ISNULL(P.data, '17530101') as dataPenultimaCompra,
		observacao,
		case when ISNULL(U.data, '17530101') = '17530101' AND ISNULL(P.data, '17530101') = '17530101'
			then 1
			else 0
		end as semCompra,
		case when isnull(U.data, '17530101') <> '17530101' OR isnull(P.data, '17530101') <> '17530101'
			then 1
			else 0
		end as comCompra

		FROM #CLIENTES C
			LEFT JOIN ultimas_compras U ON U.codigoCliente = C.codigoCliente
			LEFT JOIN penultimas_compras P ON P.codigoCliente = C.codigoCliente
	)

	SELECT
		 *
	FROM ultimas_compras_ajustadas

	WHERE 
		(semCompra = 1 AND @OpcaoCompras = 0) OR
		(comCompra = 1 AND @OpcaoCompras = 1) OR
		@OpcaoCompras = 2

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais

	DROP TABLE ##DWVendas;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
END