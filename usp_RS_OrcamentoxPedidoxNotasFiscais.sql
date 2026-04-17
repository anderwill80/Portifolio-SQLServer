/*
====================================================================================================================================================================================
WREL055 - Orcamento versus Pedido versus Notas Fiscais
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
30/01/2025 - WILLIAM
	- Troca da SP "usp_GetCodigosVendedores" pela "usp_Get_CodigosVendedores", recebendo o nome de vendedor como parametro e possibilidade de incluir vendedor 0(zero);
	- Troca da SP "usp_GetCodigosClientes" pela "usp_Get_CodigosClientes", devido a novo padrao de nomenclatura de SPs;
17/01/2025 - WILLIAM
	- Alteração nos parametros da SP "usp_GetCodigosClientes";
10/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;	
	- Uso da SP "usp_GetCodigosVendedores" para obter códigos dos vendedores conforme parametro;
	- Uso da SP "usp_GetCodigosClientes" para obter códigos dos clientes conforme parametro, considerando as empresas do grupo como clientes, caso parametro esteja marcado;
	- Inclusão de filtros nas tabelas pela empresa, utilizando o parâmetro recebido via menu do Integros(@empcod), juntamente com a SP "usp_GetCodigoEmpresaTabela";
====================================================================================================================================================================================
*/
--CREATE PROCEDURE [dbo].[usp_RS_OrcamentoxPedidoxNotasFiscais]
ALTER PROCEDURE [dbo].[usp_RS_OrcamentoxPedidoxNotasFiscais]
	@empcod smallint,
	@dataDe datetime,
	@dataAte datetime,
    @codigoVendedor varchar(500),
	@nomeVendedor varchar(60),
	@codigoCliente int,
	@nomeCliente varchar(60),	
	@grupoVendedor varchar(500),
	@incluirClienteGrupo char(1)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS002 smallint, @empresaTBS004 smallint, @empresaTBS043 smallint, @empresaTBS055 smallint, @empresaTBS067 smallint,
			@Data_De datetime, @Data_Ate datetime, @CodigosVendedor varchar(500), @VENNOM varchar(60), @CLICOD char(5), @CLINOM varchar(60),
			@GruposVendedor varchar(500), @IncluiClienteGrupo char(1);

	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @Data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));
	SET @CodigosVendedor = @codigoVendedor;
	SET @VENNOM = RTRIM(LTRIM(@nomeVendedor));
	SET @CLICOD = IIF(@codigoCliente = 0, '', convert(char(5), @codigoCliente));
	SET @CLINOM = RTRIM(LTRIM(@nomeCliente));
	SET @GruposVendedor = @grupoVendedor;
	SET @IncluiClienteGrupo = @incluirClienteGrupo;

-- Uso da funcao split, para as clausulas IN()
	-- Codigos de produto
	If object_id('TempDB.dbo.#GRUPOSVEN') is not null
		DROP TABLE #GRUPOSVEN;
	SELECT 
		elemento as gruvencod
	INTO #GRUPOSVEN FROM fSplit(@GruposVendedor, ',')

	-- Verificar se a tabela compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS043', @empresaTBS043 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS055', @empresaTBS055 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS067', @empresaTBS067 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem códigos dos vendedores	
	IF object_id('tempdb.dbo.#CodigosVendedores') is not null
		DROP TABLE #CodigosVendedores;

	CREATE TABLE #CodigosVendedores(VENCOD INT)

	INSERT INTO #CodigosVendedores
	EXEC usp_Get_CodigosVendedores @codigoEmpresa, @CodigosVendedor, @VENNOM, 'FALSE'; --FALSE = Nao incluir codigo zero

--	SELECT * FROM #CodigosVendedores
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento dos registros dos vendedores

	IF object_id('tempdb.dbo.#Vendedores') is not null
	   DROP TABLE #Vendedores;

	SELECT 
		VENCOD,
		RTRIM(LTRIM(STR(B.VENCOD))) + ' - ' + RTRIM(LTRIM(VENNOM)) AS VENNOM,
		B.GVECOD,
		ISNULL(RTRIM(LTRIM(STR(B.GVECOD))) + ' - ' + RTRIM(LTRIM(C.GVEDES)), '0 - SEM GRUPO') AS GVEDES
	INTO #Vendedores FROM TBS004 B (NOLOCK)
		LEFT JOIN TBS091 C (NOLOCK) ON B.GVECOD = C.GVECOD AND B.GVEEMPCOD = C.GVEEMPCOD

	WHERE
		VENEMPCOD = @empresaTBS004 AND
		VENCOD IN (SELECT VENCOD FROM #CodigosVendedores) AND 
		B.GVECOD IN (SELECT gruvencod FROM #GRUPOSVEN)

	UNION
	SELECT TOP 1 
		0,
		'0 - SEM VENDEDOR' AS VENNOM,
		0,
		'0 - SEM GRUPO' AS GVDES
	FROM TBS004 (NOLOCK)

	WHERE
		0 IN (SELECT VENCOD FROM #CodigosVendedores) AND 
		0 IN (SELECT gruvencod FROM #GRUPOSVEN) 

--select * FROM #Vendedores
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem códigos dos clientes	

	IF object_id('tempdb.dbo.#TBS002') is not null 	
		DROP TABLE #TBS002;	

	CREATE TABLE #TBS002 (CLICOD INT)

	INSERT INTO #TBS002
	EXEC usp_Get_CodigosClientes @codigoEmpresa, @CLICOD, @CLINOM, @IncluiClienteGrupo

--	SELECT * FROM #TBS002
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- ORÇAMENTOS

	IF OBJECT_ID('tempdb.dbo.#Orcamentos') IS NOT NULL 
		DROP TABLE #ORCAMENTOS;

	SELECT	
		ROW_NUMBER() OVER (Partition by A.VENCOD,A.ORCCLI order by ORCNUM) AS idOrcamento,
		A.VENCOD as codigoVendedor,
		VENNOM as nomeVendedor,
		GVECOD AS codigoGrupoVendedor,
		GVEDES as nomeGrupoVendedor,
		A.ORCCLI AS codigoCliente,
		rtrim(ltrim(A.ORCNOM)) AS nomeCliente,		
		ROW_NUMBER() OVER (Partition by ORCNUM order by ORCNUM) AS qtdOrcamento,
		CONVERT(CHAR(12),A.ORCDATCAD,103) AS data,
		ORCNUM as numeroOrcamento,
		CASE WHEN ORCULTITE > 0
			THEN ROUND(dbo.ORCTOTLIQ(ORCEMPCOD, ORCNUM),2)
			ELSE 0
		END as valorOrcamento,
		case when A.ORCPDVNUM <> 0
			THEN 'S'
			ELSE 'N'
		END AS gerouPedido,
		A.ORCPDVNUM AS ultimoPedidoGerado

	INTO #Orcamentos								
	FROM TBS043 A (NOLOCK)
	INNER JOIN #Vendedores B ON A.VENCOD = B.VENCOD

	WHERE 
	ORCEMPCOD = @empresaTBS043 AND	
	ORCDATCAD BETWEEN @Data_De AND @Data_Ate AND
	A.ORCCLI IN (SELECT CLICOD FROM #TBS002) AND
	ORCULTITE > 0
	
	ORDER BY
	A.VENCOD, 
	A.ORCCLI,
	'idOrcamento'

-- select * from #Orcamentos order by codigoVendedor, codigoCliente, idOrcamento
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- PEDIDOS
	IF object_id('tempdb.dbo.#Pedidos') is not null 
		drop table #Pedidos;

	SELECT	
		ROW_NUMBER() OVER (Partition by A.VENCOD,A.PDVCLICOD order by PDVNUM) AS idPedido,
		A.VENCOD as codigoVendedor,
		VENNOM as nomeVendedor,
		GVECOD AS codigoGrupoVendedor,
		GVEDES as nomeGrupoVendedor,
		A.PDVCLICOD AS codigoCliente,
		rtrim(ltrim(A.PDVCLINOM)) AS nomeCliente,		
		ROW_NUMBER() OVER (Partition by PDVNUM order by PDVNUM) AS qtdPedido,
		CONVERT(CHAR(12),A.PDVDATCAD,103) AS data,
		PDVNUM as numeroPedido,
		ROUND(dbo.PDVTOTLIQ(A.PDVEMPCOD,A.PDVNUM),2) as valorPedido,
		case when A.PDVNFSNUM <> 0
			THEN 'S'
			ELSE 'N'
		END AS gerouNota,
		A.PDVNFSNUM AS ultimaNotaGerada
	
	INTO #Pedidos		
	FROM TBS055 A (NOLOCK)
	INNER JOIN #Vendedores B ON A.VENCOD = B.VENCOD

	WHERE 
	PDVEMPCOD = @empresaTBS055 AND
	A.PDVCLICOD IN (SELECT CLICOD FROM #TBS002) AND 
	PDVDATCAD between @Data_De and @Data_Ate AND
	PDVULTITE > 0

	ORDER BY 
	A.VENCOD, 
	A.PDVCLICOD,
	'idPedido'

	-- select * from #Pedido order by codigoVendedor, codigoCliente, idPedido
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- NFS
	IF object_id('tempdb.dbo.#Notas') is not null 	
		drop table #Notas;

	SELECT
		ROW_NUMBER() OVER (Partition by A.VENCOD,A.NFSCLICOD order by NFSNUM) AS idNota,
		A.VENCOD as codigoVendedor,
		VENNOM as nomeVendedor,
		GVECOD AS codigoGrupoVendedor,
		GVEDES as nomeGrupoVendedor,
		A.NFSCLICOD AS codigoCliente,
		rtrim(ltrim(A.NFSCLINOM)) AS nomeCliente,		
		ROW_NUMBER() OVER (Partition by NFSNUM order by NFSNUM) AS qtdNota,
		CONVERT(CHAR(12),A.NFSDATEMI,103) AS data,
		NFSNUM as numeroNota,
		ROUND(dbo.NFSTOTLIQ(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER),2) as valorNota,
		case NFSTIP 
			when 'N' then 'Normal'
			when 'L' then 'Loja'
			when 'C' then 'Complementar'
			else 'indefinido'
		end tipoNota

	INTO #Notas								
	FROM TBS067 A (NOLOCK) 
	INNER JOIN TBS080 B (NOLOCK) ON A.NFSEMPCOD = B.ENFEMPCOD AND A.NFSNUM = B.ENFNUM AND A.SNESER = B.SNESER AND A.SNEEMPCOD = B.SNEEMPCOD
	INNER JOIN #Vendedores D ON A.VENCOD = D.VENCOD 

	WHERE 
	NFSEMPCOD = @empresaTBS067 AND
	A.NFSCLICOD IN (SELECT CLICOD FROM #TBS002) AND 
	A.NFSDATEMI BETWEEN @Data_De and @Data_Ate AND 
	B.ENFTIPDOC = 1 AND -- tipo de saida
	B.ENFSIT = 6 AND -- autorizada
	B.ENFFINEMI = 1

	ORDER BY 
	A.VENCOD, 
	A.NFSCLICOD,
	'idNota'
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA FINAL AGRUPADO POR VENDEDOR

	SELECT 
		ISNULL(ISNULL(A.codigoGrupoVendedor,B.codigoGrupoVendedor),C.codigoGrupoVendedor) AS codigoGrupoVendedor,
		ISNULL(ISNULL(A.nomeGrupoVendedor,B.nomeGrupoVendedor),C.nomeGrupoVendedor) AS nomeGrupoVendedor,
		ISNULL(ISNULL(A.codigoVendedor,B.codigoVendedor),C.codigoVendedor) AS codigoVendedor,
		ISNULL(ISNULL(A.nomeVendedor,B.nomeVendedor),C.nomeVendedor) AS nomeVendedor,
		ISNULL(ISNULL(A.codigoCliente,B.codigoCliente),C.codigoCliente) AS codigoCliente,
		ISNULL(ISNULL(A.nomeCliente,B.nomeCliente),C.nomeCliente) AS nomeCliente,

		A.qtdOrcamento,
		A.data as dataOrcamento,
		A.numeroOrcamento,
		A.valorOrcamento,
		A.gerouPedido, 
		A.ultimoPedidoGerado,

		B.qtdPedido,
		B.data as dataPedido,
		B.numeroPedido,
		B.valorPedido,
		B.gerouNota,
		B.ultimaNotaGerada ,

		C.qtdNota,
		C.data as dataNota,
		C.numeroNota,
		C.valorNota,
		C.tipoNota

	FROM #Orcamentos A 
	FULL OUTER JOIN #Pedidos B ON A.idOrcamento = B.idPedido and A.codigoVendedor = B.codigoVendedor and A.codigoCliente = B.codigoCliente
	FULL OUTER JOIN #Notas C ON isnull(A.idOrcamento,B.idPedido) = C.idNota and isnull(A.codigoVendedor,B.codigoVendedor) = C.codigoVendedor and isnull(A.codigoCliente,B.codigoCliente) = C.codigoCliente

	order by
	ISNULL(ISNULL(A.codigoGrupoVendedor,B.codigoGrupoVendedor),C.codigoGrupoVendedor), 
	ISNULL(ISNULL(A.codigoVendedor,B.codigoVendedor),C.codigoVendedor),
	ISNULL(ISNULL(A.codigoCliente,B.codigoCliente),C.codigoCliente),
	isnull(isnull(A.idOrcamento,B.idPedido),C.idNota)
END