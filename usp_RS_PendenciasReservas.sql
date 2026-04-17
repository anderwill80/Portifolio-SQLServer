/*
====================================================================================================================================================================================
WREL142 - Pendencias e Reservas
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
30/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
	- Uso da SP "usp_Get_CodigosVendedores" e "usp_Get_CodigosClientes";
	- Uso da função "fSplit" para transformar os filtros multi-valores em tabelas, para facilitar condições via cláusula "IN()"
	- Alteracao nos valores padrao das datas de/ate, quando recebido como nulos;
19/02/2024	ANDERSON WILLIAM
	- Conversão para Stored procedure
	- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
	- Uso da "uusp_GetCodigoEmpresaTabela" em vez de "usp_GetCodigoEmpresaTabela", SQL deixa de verificar SP no BD Master, buscando direto no SIBD
	- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas										
====================================================================================================================================================================================
*/
--drop proc usp_RS_PendenciasReservas2
ALTER PROC [dbo].[usp_RS_PendenciasReservas]
--CREATE PROC [dbo].[usp_RS_PendenciasReservas2]
	@empcod int,
	@dataDe datetime = null,
	@dataAte datetime = null,
	@codigoVendedor varchar(200) = '',
	@grupoVendedor varchar(200),
	@nomeVendedor varchar(60) = '',	
	@codigoCliente varchar(200) = '',	
	@categoriaCliente varchar(200),
	@nomeCliente varchar(60)		= '',
	@numeroPedido int				= 0,
	@codigoProduto varchar(20)		= '',
	@descricaoProduto varchar(60)	= '',
	@codigoMarca int				= 0,
	@nomeMarca varchar(30)			= '',
	@situacao char(1),
	@conferidos char(1)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	DECLARE @codigoEmpresa smallint, @empresaTBS002 int, @empresaTBS004 int, @empresaTBS055 int,
			@PDVDATCAD_DE datetime, @PDVDATCAD_ATE datetime, @codigosVendedores varchar(200), @VENNOM varchar(60), 	@GruposVendedor varchar(200), @CategoriasCliente varchar(200),
			@codigosClientes varchar(200), @CLINOM varchar(60), @PDVNUM int, @PROCOD varchar(20), @PRPPRODES varchar(60), @PRPMARCOD int, @PRPMARNOM varchar(30), @PRPSIT char(1),
			@Query nvarchar (MAX), @ParmDef nvarchar (500);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	Set @PDVDATCAD_DE = (SELECT ISNULL(@dataDe, '17530101'))
	Set @PDVDATCAD_ATE = (SELECT ISNULL(@dataAte, GETDATE()));
	Set @codigosVendedores = @codigoVendedor;
	Set @VENNOM = @nomeVendedor;
	SET @GruposVendedor = @grupoVendedor;
	Set @codigosClientes = @codigoCliente
	Set @CLINOM	= @nomeCliente;
	SET @CategoriasCliente = @categoriaCliente;
	Set @PDVNUM = @numeroPedido

	Set @PROCOD				= LTRIM(RTRIM(@codigoProduto))
	Set @PRPPRODES			= UPPER(LTRIM(RTRIM(@descricaoProduto)))
	Set @PRPMARCOD			= @codigoMarca
	Set @PRPMARNOM			= UPPER(LTRIM(RTRIM(@nomeMarca)))
	Set @PRPSIT				= UPPER(@situacao)
	
-- Uso de funcao fSplit() para uso nas clausulas IN()
	-- Grupo de vendedores
	IF OBJECT_ID('tempdb.dbo.#GRUPOSVEN') IS NOT NULL
		DROP TABLE #GRUPOSVEN;	
	SELECT 
		elemento AS valor
	INTO #GRUPOSVEN FROM fSplit(@GruposVendedor, ',')
	-- Gategorias de clientes
	IF OBJECT_ID('tempdb.dbo.#CATEGORIAS') IS NOT NULL
		DROP TABLE #CATEGORIAS;	
	SELECT 
		elemento AS valor
	INTO #CATEGORIAS FROM fSplit(@CategoriasCliente, ',')
	
-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS055', @empresaTBS055 output;	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem codigos dos vendedores via SP, incluindo codigo 0(zero)
	IF OBJECT_ID('tempdb.dbo.#CODVEN') IS NOT NULL
		DROP TABLE #CODVEN;

	CREATE TABLE #CODVEN (VENCOD INT)
	
	INSERT INTO #CODVEN
	EXEC usp_Get_CodigosVendedores @codigoEmpresa, @codigosVendedores, @VENNOM, @pComZero = 'TRUE';	-- Inclui codigo 0(zero);

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento dos vendedores

	IF OBJECT_ID('tempdb.dbo.#VENDEDORES') IS NOT NULL 
		DROP TABLE #VENDEDORES
	
	-- Select para criar estrutura da tabela temporária # via "SELECT TOP 0"
	SELECT
		VENEMPCOD as empresa,
		VENCOD as codigoVendedor,
		RTRIM(VENNOM) as nomeVendedor	
	INTO #VENDEDORES FROM TBS004 A (NOLOCK)
	WHERE 
		VENEMPCOD = @empresaTBS004 AND
		VENCOD IN(SELECT VENCOD FROM #CODVEN) AND
		GVECOD IN(SELECT valor FROM #GRUPOSVEN) 

	UNION
	SELECT TOP 1
		VENEMPCOD as empresa,
		0 AS codigoVendedor,
		'0 - SEM VENDEDOR' AS nomeVendedor
	FROM TBS004 (NOLOCK)

	WHERE
		0 IN (SELECT VENCOD FROM #CODVEN)	
		-- verificar a inclusao do 0 in(gruposvendedor)
	
--	SELECT * FROM #VENDEDORES
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem a lista de clientes 

	IF OBJECT_ID('tempdb.dbo.#CODCLI') IS NOT NULL
		DROP TABLE #CODCLI;

	CREATE TABLE #CODCLI (CLICOD INT)

	INSERT INTO #CODCLI
	EXEC usp_Get_CodigosClientes @codigoEmpresa, @codigosClientes, @CLINOM, 'S' -- Considerar empresas do grupo BMPT como clientes

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinando os clientes

	If OBJECT_ID('tempdb.dbo.#TBS002') IS NOT NULL 
		DROP TABLE #TBS002;
	
	SELECT
		CLIEMPCOD as empresa,
		CLICOD as codigoCliente,
		RTRIM(CLINOM) as nomeCliente
	INTO #TBS002 FROM TBS002 A (NOLOCK) 

	WHERE
		CLIEMPCOD = @empresaTBS002 AND
		CLICOD IN (SELECT CLICOD FROM #CODCLI) AND
		CATCOD IN (SELECT valor FROM #CATEGORIAS)

--	select * from #TBS002
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtrar os pedidos de vendas

	IF OBJECT_ID('tempdb.dbo.#PEDIDOVENDAS') IS NOT NULL 
		DROP TABLE #PEDIDOVENDAS;

	-- Cria somente a estrutura da #Pedidos via "TOP 0" ou "Where 1=0"
	SELECT TOP 0
		A.PDVEMPCOD as empresa,
		A.PDVDATCAD as dataCadastro,
		A.PDVNUM as numeroPedido,
		A.PDVBLQCPG as bloqueioCondicaoPagto,
		A.PDVBLQCRE as bloqueioCredito,
		B.PDVITEM as item,
		B.PDVBLQPRE as bloqueioPreco,
		PDVPRE as preco,
		A.VENCOD as codigoVendedor, 
		case when A.VENCOD = 0
			then 'SEM VENDEDOR'
			else D.nomeVendedor
		end as nomeVendedor,
		A.PDVCLICOD as codigoCliente,
		rtrim(A.PDVCLINOM) as nomeCliente,
		A.PDVREQNOM as requisitante, 
		B.PDVNUMPEDCOM as pedidoCliente
	INTO #PEDIDOVENDAS FROM TBS055 A (NOLOCK)
		INNER JOIN TBS0551 B (NOLOCK) ON A.PDVEMPCOD = B.PDVEMPCOD and A.PDVNUM = B.PDVNUM
		INNER JOIN #VENDEDORES D (NOLOCK) ON A.VENEMPCOD = D.empresa and A.VENCOD = D.codigoVendedor

	Set @Query	= N'	
		INSERT INTO #PEDIDOVENDAS
	
		SELECT
			A.PDVEMPCOD as empresa,
			A.PDVDATCAD as dataCadastro,
			A.PDVNUM as numeroPedido,
			A.PDVBLQCPG as bloqueioCondicaoPagto,
			A.PDVBLQCRE as bloqueioCredito,
			B.PDVITEM as item,
			B.PDVBLQPRE as bloqueioPreco,
			PDVPRE as preco,
			A.VENCOD as codigoVendedor, 
			case when A.VENCOD = 0
				then ''SEM VENDEDOR''
				else D.nomeVendedor
			end as nomeVendedor,
			A.PDVCLICOD as codigoCliente,
			RTRIM(A.PDVCLINOM) as nomeCliente,
			A.PDVREQNOM as requisitante, 
			B.PDVNUMPEDCOM as pedidoCliente

		FROM TBS055 A (NOLOCK)
			INNER JOIN TBS0551 B (NOLOCK) on A.PDVEMPCOD = B.PDVEMPCOD AND A.PDVNUM = B.PDVNUM
			INNER JOIN #VENDEDORES D (NOLOCK) on A.VENEMPCOD = D.empresa and A.VENCOD = D.codigoVendedor

		WHERE
			A.PDVEMPCOD	= @empresaTBS055 AND
			A.PDVDATCAD	BETWEEN @PDVDATCAD_DE and @PDVDATCAD_ATE AND
			A.PDVCLICOD IN(SELECT codigoCliente FROM #TBS002) AND
			EXISTS (select 1 from TBS058 C (nolock) WHERE A.PDVEMPCOD = C.PRPEMP and A.PDVNUM = C.PRPNUM)
			'
			+
			IIf(@PDVNUM <= 0, '', ' AND A.PDVNUM = @PDVNUM')
			+
			'
			ORDER BY 
				A.PDVEMPCOD,
				A.PDVDATCAD,
				A.PDVNUM
			'

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS055 int, @PDVDATCAD_DE datetime, @PDVDATCAD_ATE datetime, @PDVNUM int'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS055, @PDVDATCAD_DE, @PDVDATCAD_ATE, @PDVNUM
	
--	SELECT * FROM #PEDIDOVENDAS	 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	Set @Query	= N'
		SELECT 
		PRPSIT as situacao,
		dataCadastro,
		PRPNUM as numeroPedido,
		bloqueioCondicaoPagto,
		bloqueioCredito,
		codigoVendedor, 
		nomeVendedor,
		codigoCliente,
		nomeCliente,
		PRPITEM as item, 
		rtrim(PROCOD) as codigoProduto, 
		rtrim(PRPPRODES) as descricaoProduto, 
		PRPMARCOD as codigoMarca,
		rtrim(PRPMARNOM) as nomeMarca,
		B.PRPMOVEST as movimentaEstoque,
		PRPESTLOC as localEstoque,
		PRPQTD as quantidade,
		PRPUNI as unidadeMedida, 
		PRPQTDEMB as quantidadeEmbalagem,
		bloqueioPreco,
		B.PRPPRELIQ as precoLiquido,
		B.PRPPRELIQ * PRPQTD as total,
		PRPQTDCONF as quantidadeConferida,
		case when PRPSIT = ''P'' then 1 else 0 end as qtdPendente,
		case when PRPSIT = ''R'' then 1 else 0 end as qtdReservada,
		convert(decimal(12,4), substring(dbo.[SaldosEmEstoque](B.PROCOD, ''2''), 25, 12)) as saldoDisponivelLoja,
		requisitante, 
		pedidoCliente,
		B.PRPDATREG as dataGravacao

		FROM #PEDIDOVENDAS A 
			INNER JOIN TBS058 B (NOLOCK) on A.empresa = B.PRPEMP and A.numeroPedido = B.PRPNUM and A.item = B.PRPITEM
		WHERE 
			(case when PRPQTDCONF > 0 
				then 
					case when PRPQTD <> PRPQTDCONF
						then ''P''
						else ''S''
					end 
				else ''N''
			end = @conferidos OR @conferidos = ''T'')
			'
			+
			IIf(@PROCOD = '', '', ' AND PROCOD = @PROCOD')
			+
			IIf(@PRPPRODES = '', '', ' AND PRPPRODES LIKE @PRPPRODES')
			+
			IIf(@PRPMARCOD <= 0, '', ' AND PRPMARCOD = @PRPMARCOD')
			+
			IIf(@PRPMARNOM = '', '', ' AND PRPMARNOM LIKE @PRPMARNOM')
			+
			IIf(@PRPSIT = 'T', '', ' AND PRPSIT = @PRPSIT')						
			+
			'
		ORDER BY
			PRPEMP,
			PRPSIT,
			PRPNUM,
			PRPITEM
		'
	-- select @Query

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@conferidos char(1), @PROCOD varchar(20), @PRPPRODES varchar(60), @PRPMARCOD int, @PRPMARNOM varchar(30), @PRPSIT char(1)'

	EXEC sp_executesql @Query, @ParmDef, @conferidos, @PROCOD, @PRPPRODES, @PRPMARCOD, @PRPMARNOM, @PRPSIT
End