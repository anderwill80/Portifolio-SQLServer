/*
====================================================================================================================================================================================
WREL011 - Compras por Estado - Municipio - Fornecedor - Nota
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
16/01/2025 - WILLIAM
	- Alteração nos parametros da SP "usp_FornecedoresGrupo";

12/12/2024 - WILLIAM
	- Correção nos filtros da TBS080, estava com data fixa;

20/06/2024 - WILLIAM
	- Inclusão para obter notas de compra NFETIP = 'N', estava dando erro quando filtrava notas de complemento, pois quantidade de entrada é zero;
	- Uso da SP "usp_FornecedoresGrupo";
	- Conversão para Stored procedure
	- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", SQL deixa de verificar SP no BD Master, buscando direto no SIBD
	- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas																				
************************************************************************************************************************************************************************************
*/
alter proc [dbo].usp_RS_ComprasEstadoMunicipioFornecedorNF(
--create proc [dbo].usp_RS_ComprasEstadoMunicipioFornecedorNF(
	@empcod smallint,
	@data1de datetime,
	@data1ate datetime = null,
	@GRUPO smallint
	)
as

begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais

	declare	@empresaTBS006 smallint, @empresaTBS010 smallint, @empresaTBS059 smallint, @empresaTBS080 smallint,
			@Query nvarchar (MAX), @ParmDef nvarchar (500),
			@codigoEmpresa smallint, @DATA_DE datetime, @DATA_ATE datetime, @ForGRUPO smallint
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribuições das variáveis

	SET @codigoEmpresa = @empcod
	SET @DATA_DE = @data1de
	SET @DATA_ATE = (select isnull(@data1ate, GETDATE()))
	SET @ForGRUPO = @GRUPO

	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS006', @empresaTBS006 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS059', @empresaTBS059 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS080', @empresaTBS080 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CFOPS de compras
	If object_id('tempdb.dbo.#NFECFOP') is not null	
		drop table #NFECFOP	
   
	create table #NFECFOP (NFECFOP CHAR(3), TIPO CHAR(1)) --, NFECFOPDES VARCHAR(45))

	-- ENTRADA
	INSERT INTO #NFECFOP VALUES ('101','E') -- , 'COMPRA PARA INDUSTRIALIZACAO') -- NAO DEVE DEVE SER USADO
	INSERT INTO #NFECFOP VALUES ('102','E') -- , 'COMPRA PARA COMERCIALIZACAO')
	INSERT INTO #NFECFOP VALUES ('117','E') -- , 'COMPRA FUTURA (MERCADORIA)')
	INSERT INTO #NFECFOP VALUES ('122','E') -- , 'COMPRA PARA INDUSTRIALIZACAO')
	INSERT INTO #NFECFOP VALUES ('403','E') -- , 'COMPRA PARA COMERCIALIZACAO ST')
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TBS080 Notas eletronicas autorizadas

	If object_id('tempdb.dbo.#TBS080') is not null	
		drop table #TBS080
   
	SELECT 
	ENFNUM,
	SNEEMPCOD,
	SNESER,
	ENFTIPDOC,
	ENFFINEMI,
	ENFCODDES,
	ENFCNPJCPF

	INTO #TBS080

	FROM TBS080 (NOLOCK)

	WHERE 
	ENFEMPCOD = 0 AND
	ENFDATEMI BETWEEN @DATA_DE AND @DATA_ATE AND
	ENFSIT = 6 AND 
	ENFTIPDOC = 0 AND
	ENFFINEMI <> 4 

	--SELECT * FROM #TBS080
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA DE FORNECEDORES 

	If object_id('tempdb.dbo.#TBS006') is not null
		drop table #TBS006
   
	SELECT 
	FORCOD,
	RTRIM(LTRIM(FORNOM)) AS FORNOM,
	MUNCOD

	INTO #TBS006

	FROM TBS006 (NOLOCK) 
	WHERE FOREMPCOD = @empresaTBS006
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA DE PRODUTOS 
 
	If object_id('tempdb.dbo.#TBS010') is not null
		drop table #TBS010	
   
	SELECT 
	PROCOD,
	PROUM1

	INTO #TBS010

	FROM TBS010 (NOLOCK) 
	WHERE PROEMPCOD = @empresaTBS010
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Fornecedores DO GRUPO

	If object_id('tempdb.dbo.#GRUPOFOR') is not null
		drop table #GRUPOFOR
	
	CREATE TABLE #GRUPOFOR (FORCOD INT)

	IF @ForGRUPO = 1 -- Sim 
	BEGIN 
		SET @Query = 'SELECT TOP 1
					-1 AS CLICOD			
					FROM TBS010 (nolock)'
	END

	If object_id('tempdb.dbo.#CodigosFornecedorGrupo') is not null
		drop table #CodigosFornecedorGrupo	

	create table #CodigosFornecedorGrupo (codigo int)
	
	insert into #CodigosFornecedorGrupo
	EXEC usp_FornecedoresGrupo @codigoEmpresa


	IF @ForGRUPO = 0 -- Não
	BEGIN 
		SET @Query = 'SELECT FORCOD AS CLICOD 
					FROM TBS006 (nolock)
					WHERE 
					FORCOD in (select codigo from #CodigosFornecedorGrupo)'
	END

	INSERT INTO #GRUPOFOR
	EXEC (@Query)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CONTABILIZAR COMPRAS

	if object_id('TempDB.dbo.#NFE') is not null
	   drop table #NFE

	SELECT
	B.NFEESTORI AS UF,
	C.MUNCOD,
	(SELECT RTRIM(LTRIM(MUNNOM)) FROM TBS003 E (NOLOCK) WHERE E.MUNCOD = C.MUNCOD) AS MUNNOM,
	B.NFECOD AS NFSCLICOD,
	B.NFENOM AS NFSCLINOM,
	B.NFENUM AS NFSNUM,
	A.PROCOD ,
	A.NFEDES AS NFSPRODES,
	E.PROUM1,
	NFETOTOPEITE / A.NFEQTD AS NFEPRE,
	A.NFEQTD * A.NFEQTDEMB AS NFSQTDVEN,
	NFETOTOPEITE,
	A.NFENCMXML,
	A.NFECSTXML,
	CASE WHEN ISNULL(A.NFEPCRESN, 0) > 0 
		THEN A.NFEPCRESN
		ELSE A.NFEPERICMSXML
	END NFEPERICMSXML

	INTO #NFE
	FROM
	TBS0591 A (NOLOCK) 
	INNER JOIN TBS059 B (NOLOCK) ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFECOD = B.NFECOD AND A.NFENUM = B.NFENUM AND A.NFETIP = B.NFETIP AND A.SERCOD = B.SERCOD AND A.SEREMPCOD = B.SEREMPCOD
	LEFT JOIN #TBS080 D (NOLOCK) ON A.NFENUM = D.ENFNUM AND A.NFECOD = D.ENFCODDES
	LEFT JOIN #TBS006 C (NOLOCK) ON B.NFECOD = C.FORCOD
	LEFT JOIN #TBS010 E (NOLOCK) ON A.PROCOD = E.PROCOD
		
	WHERE
	A.NFEEMPCOD = @empresaTBS059 AND
	A.NFETIP = 'N' AND
	B.NFEDATEFE BETWEEN @DATA_DE and @DATA_ATE AND 
	B.NFENOM NOT LIKE ('%TANBY%') AND
	(D.ENFTIPDOC IS NOT NULL OR (NFENOSFOR <> 'S' AND B.NFECAN <> 'S' AND NFEDATEFE <> '' )) AND
	SUBSTRING(A.NFECFOP,3,3) COLLATE DATABASE_DEFAULT IN (SELECT NFECFOP FROM #NFECFOP WHERE TIPO = 'E') AND
	B.NFECOD NOT IN (SELECT FORCOD FROM #GRUPOFOR)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT * FROM #NFE
End
