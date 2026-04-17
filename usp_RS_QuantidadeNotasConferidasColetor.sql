/*
====================================================================================================================================================================================
WREL117 - Quantidade de notas conferidas com o coletor
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
17/01/2025 - WILLIAM
	- Uso da SP "usp_FornecedoresGrupo";  
	- Uso da SP "usp_GetCodigosFornecedores"; 
	- Alteração nos parametros da SP "usp_GetCodigosClientes";	
	- Uso da função NULLIF() para evitar divisão por zero;
16/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parametros de entrada da SP;	
	- Uso da SP "usp_GetCodigosClientes";  
************************************************************************************************************************************************************************************
*/
--CREATE PROCEDURE [dbo].[usp_RS_QuantidadeNotasConferidasColetor]
ALTER PROCEDURE [dbo].[usp_RS_QuantidadeNotasConferidasColetor]
	@empcod smallint,	
	@dataEfetivacaoDe datetime,
	@dataEfetivacaoAte datetime,
	@tipoNf char(1),
	@GRUPO char(1)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, 
			@DataEfetivacao_De datetime, @DataEfetivacao_Ate datetime, @TipoNota char(1), @CliForGRUPO char(1),
			@cmdSQL varchar(MAX), @nomeEmpresa varchar(40);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @DataEfetivacao_De = (SELECT ISNULL(@dataEfetivacaoDe, '17530101'));
	SET @DataEfetivacao_Ate = (SELECT ISNULL(@dataEfetivacaoAte, GETDATE()));
	SET @TipoNota = @tipoNf;
	SET @CliForGRUPO = @GRUPO;	

	SET @nomeEmpresa = (SELECT TOP 1 RTRIM(LTRIM(EMPNOMFAN)) FROM TBS023 (nolock) WHERE EMPCOD = @codigoEmpresa)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem somente empresas do grupo que sejam clientes

	IF object_id('tempdb.dbo.#ClientesGrupo') IS NOT NULL
		drop table #ClientesGrupo;

	CREATE TABLE #ClientesGrupo (CLICOD INT)

	IF @CliForGRUPO = 'S'
		INSERT INTO #ClientesGrupo
		EXEC usp_ClientesGrupo @codigoEmpresa;

	-- SELECT * FROM #ClientesGrupo

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem códigos dos cliente que não sejam empresas do grupo conforme filtro utilizando a SP

	IF object_id('tempdb.dbo.#ClientesNormais') IS NOT NULL
		DROP TABLE #ClientesNormais;	
	
	CREATE TABLE #ClientesNormais (CLICOD int)

	INSERT INTO #ClientesNormais
	EXEC usp_GetCodigosClientes @codigoEmpresa, '', '', 'N'	-- Não contabiliza empresas do grupo

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Mescla clientes normais e empresas do grupo

	IF object_id('tempdb.dbo.#Clientes') IS NOT NULL
		DROP TABLE #Clientes;

	select 
		* 
	INTO #Clientes FROM #ClientesNormais 

	UNION
	SELECT 
		* 
	FROM #ClientesGrupo

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Fornecedores como empresas do grupo

	IF object_id('tempdb.dbo.#Fornecedoresgrupo') IS NOT NULL
		DROP TABLE #FornecedoresGrupo;

	CREATE TABLE #FornecedoresGrupo (FORCOD INT)

	IF @CliForGRUPO = 'S'
		INSERT INTO #FornecedoresGrupo
		EXEC  usp_FornecedoresGrupo @codigoempresa;

	-- SELECT * FROM #FornecedoresGrupo

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem códigos dos fornecedores que não sejam empresas do grupo conforme filtro utilizando a SP

	IF object_id('tempdb.dbo.#FornecedoresNormais') IS NOT NULL
		DROP TABLE #FornecedoresNormais;	
	
	CREATE TABLE #FornecedoresNormais (FORCOD int)

	INSERT INTO #FornecedoresNormais
	EXEC usp_GetCodigosFornecedores 1, '', '', 'N'	-- Não contabiliza empresas do grupo

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Mescla fornecedores normais e empresas do grupo

	IF object_id('tempdb.dbo.#Fornecedores') IS NOT NULL
		DROP TABLE #Fornecedores;

	SELECT 
		* 	
	INTO #Fornecedores FROM #FornecedoresNormais 
	
	UNION
	SELECT 
		* 
	FROM #FornecedoresGrupo

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem as notas de entrada

	IF object_id('tempdb.dbo.#TBS059') IS NOT NULL
		DROP TABLE #TBS059;

	SELECT
		NFECHAACE,
		NFECOD,
		NFETIP,
		CASE WHEN NFECONFIS = 0 
			THEN 1
			ELSE 0
		END AS semConferencia,
		CASE WHEN NFECONFIS = 1 
			THEN 1
			ELSE 0
		END AS comConferenciaSemDivergencia,
		CASE WHEN NFECONFIS = 2 
			THEN 1
			ELSE 0
		END AS comConferenciaComDivergencia,

		CASE WHEN NFECONFIS = 0 AND NFECOD IN (SELECT CLICOD FROM #ClientesNormais)
			THEN 1
			ELSE 0
		END AS semConferenciaNormal,
		CASE WHEN NFECONFIS = 1 AND NFECOD IN (SELECT CLICOD FROM #ClientesNormais)
			THEN 1
			ELSE 0
		END AS comConferenciaSemDivergenciaNormal,
		CASE WHEN NFECONFIS = 2 AND NFECOD IN (SELECT CLICOD FROM #ClientesNormais)
			THEN 1
			ELSE 0
		END AS comConferenciaComDivergenciaNormal,

		CASE WHEN NFECONFIS = 0 AND NFECOD IN (SELECT CLICOD FROM #ClientesGrupo)
			THEN 1
			ELSE 0
		END AS semConferenciaGrupo,
		CASE WHEN NFECONFIS = 1 AND NFECOD IN (SELECT CLICOD FROM #ClientesGrupo)
			THEN 1
			ELSE 0
		END AS comConferenciaSemDivergenciaGrupo,
		CASE WHEN NFECONFIS = 2 AND NFECOD IN (SELECT CLICOD FROM #ClientesGrupo)
			THEN 1
			ELSE 0
		END AS comConferenciaComDivergenciaGrupo
	INTO #TBS059 FROM TBS059 (NOLOCK) 

	WHERE
	NFEDATEFE BETWEEN @DataEfetivacao_De AND @DataEfetivacao_Ate AND
	NFECAN <> 'S' AND
	NFETIP = 'D' AND 
	NFECOD IN (SELECT CLICOD FROM #Clientes) AND 
	NFETIP NOT IN (@TipoNota)

	UNION 
	SELECT
		NFECHAACE,
		NFECOD,
		NFETIP,
		CASE WHEN NFECONFIS = 0 
			THEN 1
			ELSE 0
		END AS semConferencia,
		CASE WHEN NFECONFIS = 1 
			THEN 1
			ELSE 0
		END AS comConferenciaSemDivergencia,
		CASE WHEN NFECONFIS = 2 
			THEN 1
			ELSE 0
		END AS comConferenciaComDivergencia,

		CASE WHEN NFECONFIS = 0 AND NFECOD IN (SELECT FORCOD FROM #FornecedoresNormais)
			THEN 1
			ELSE 0
		END AS semConferenciaNormal,
		CASE WHEN NFECONFIS = 1 AND NFECOD IN (SELECT FORCOD FROM #FornecedoresNormais)
			THEN 1
			ELSE 0
		END AS comConferenciaSemDivergenciaNormal,
		CASE WHEN NFECONFIS = 2 AND NFECOD IN (SELECT FORCOD FROM #FornecedoresNormais)
			THEN 1
			ELSE 0
		END AS comConferenciaComDivergenciaNormal,

		CASE WHEN NFECONFIS = 0 AND NFECOD IN (SELECT FORCOD FROM #FornecedoresGrupo)
			THEN 1
			ELSE 0
		END AS semConferenciaGrupo,
		CASE WHEN NFECONFIS = 1 AND NFECOD IN (SELECT FORCOD FROM #FornecedoresGrupo)
			THEN 1
			ELSE 0
		END AS comConferenciaSemDivergenciaGrupo,
		CASE WHEN NFECONFIS = 2 AND NFECOD IN (SELECT FORCOD FROM #FornecedoresGrupo)
			THEN 1
			ELSE 0
		END AS comConferenciaComDivergenciaGrupo
	FROM TBS059 (NOLOCK) 

	WHERE
	NFEDATEFE between @DataEfetivacao_De and @DataEfetivacao_Ate and 
	NFECAN <> 'S' AND
	NFETIP <> 'D' AND 
	NFECOD IN (SELECT FORCOD FROM #Fornecedores) AND 
	NFETIP NOT IN (@TipoNota)

--	select * from #TBS059

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	--if object_id('tempdb.dbo.#Conferencia') is not null
	--begin
	--	drop table #Conferencia
	--end

	SELECT 
		dbo.PrimeiraMaiuscula(@nomeEmpresa) as Empresa,
		sum(semConferencia) as 'Sem Conferencia',
		sum(comConferenciaSemDivergencia) + sum(comConferenciaComDivergencia) as 'Com Conferencia', 
		sum(comConferenciaSemDivergencia) + sum(comConferenciaComDivergencia) + sum(semConferencia) as 'Total',
		ISNULL(sum(semConferencia) * 100 / NULLIF((sum(comConferenciaSemDivergencia) + sum(comConferenciaComDivergencia) + sum(semConferencia)),0), 0)  as 'Sem Conferencia%',
		ISNULL((sum(comConferenciaSemDivergencia) + sum(comConferenciaComDivergencia)) * 100 / NULLIF((sum(comConferenciaSemDivergencia) + sum(comConferenciaComDivergencia) + sum(semConferencia)),0), 0) as 'Com Conferencia%',
		'100' as 'Total%',

		sum(semConferenciaGrupo) as 'Sem Conferencia Grupo',
		sum(comConferenciaSemDivergenciaGrupo) + sum(comConferenciaComDivergenciaGrupo) as 'Com Conferencia Grupo', 
		sum(comConferenciaSemDivergenciaGrupo) + sum(comConferenciaComDivergenciaGrupo) + sum(semConferenciaGrupo) as 'Total Grupo',
		ISNULL(sum(semConferenciaGrupo) * 100 / NULLIF((sum(comConferenciaSemDivergenciaGrupo) + sum(comConferenciaComDivergenciaGrupo) + sum(semConferenciaGrupo)),0), 0) as 'Sem Conferencia Grupo%' ,
		ISNULL((sum(comConferenciaSemDivergenciaGrupo) + sum(comConferenciaComDivergenciaGrupo)) * 100 / NULLIF((sum(comConferenciaSemDivergenciaGrupo) + sum(comConferenciaComDivergenciaGrupo) + sum(semConferenciaGrupo)), 0), 0) as 'Com Conferencia Grupo%',

		sum(semConferenciaNormal) as 'Sem Conferencia Normal',
		sum(comConferenciaSemDivergenciaNormal) + sum(comConferenciaComDivergenciaNormal) as 'Com Conferencia Normal', 
		sum(comConferenciaSemDivergenciaNormal) + sum(comConferenciaComDivergenciaNormal) + sum(semConferenciaNormal) as 'Total Normal',
		ISNULL(sum(semConferenciaNormal) * 100 / NULLIF((sum(comConferenciaSemDivergenciaNormal) + sum(comConferenciaComDivergenciaNormal) + sum(semConferenciaNormal)), 0), 0)  as 'Sem Conferencia Normal%' ,
		ISNULL((sum(comConferenciaSemDivergenciaNormal) + sum(comConferenciaComDivergenciaNormal)) * 100 / NULLIF((sum(comConferenciaSemDivergenciaNormal) + sum(comConferenciaComDivergenciaNormal) + sum(semConferenciaNormal)), 0), 0)  as 'Com Conferencia Normal%'	
	FROM #TBS059

END