/*
===================================================================================================================================================================================
Orcamento escolar
===================================================================================================================================================================================
Historico de alteracoes
===================================================================================================================================================================================
08/04/2025 WILLIAM
	- Inclusao dos dados do vendedor, pois estava fixo nos layouts de TM e TT, que sera obtido do orçamento original;
	- Inclusao de campo no select final, para indicar qual empresa e vencedora, para que possamos imprimir os dados do vendedor;
26/03/2025 WILLIAM
	- Inclusao dos novos campos referentes a Winpack e Bestbag;
10/02/2025 WILLIAM
	- Inclusao do endereco de entrega do cliente, desde que esteja preenchido no orcamento;
09/10/2024 WILLIAM
	- Obter prazo de entrega, validade da proposta e descrição da condição de pagamento do orçamento original;
03/07/2024 WILLIAM
	- Listagem dos itens do orcamento escolar, utilizado para licitacoes para escolas;
===================================================================================================================================================================================
*/
--ALTER PROC [dbo].[usp_RS_OrcamentoEscolar_DEBUG]
ALTER proc [dbo].[usp_RS_OrcamentoEscolar]
	@nID int	
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------
	declare	@ID int

	-- Atribuicoes para desabilitar o "Parameter Sniffing" do SQL
	SET @ID = @nID

------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Itens do orcamento(auxiliar)

	IF OBJECT_ID('tempdb.dbo.#ORCAMENTOAUX') IS NOT NULL
		DROP TABLE #ORCAMENTOAUX;

	SELECT 	
		num_orca_origem,
		ISNULL(data_tanby, '17530101') AS data_tanby,
		ISNULL(total_tanby, 0) AS total_tanby,
		ISNULL(data_misaspel, '17530101') AS data_misaspel,
		ISNULL(total_misaspel, 0) AS total_misaspel,
		ISNULL(data_papelyna, '17530101') AS data_papelyna,
		ISNULL(total_papelyna, 0) AS total_papelyna,
		ISNULL(data_winpack, '17530101') AS data_winpack,
		ISNULL(total_winpack, 0) AS total_winpack,
		ISNULL(data_bestbag, '17530101') AS data_bestbag,
		ISNULL(total_bestbag, 0) AS total_bestbag,
		ORCCLI AS CLICOD,
		ORCENDENTCOD,
		RTRIM(ISNULL(CPGDES, '')) AS CPGDES,
		ORCPRAENT,
		ORCVALPRO,
		VENCOD,
		A.*
	INTO #ORCAMENTOAUX 	FROM orca_esc_det A (NOLOCK)	
		INNER JOIN orca_esc B (NOLOCK) ON id_orca = id
		INNER JOIN TBS043 C (NOLOCK)  ON ORCNUM = num_orca_origem
		LEFT JOIN TBS008 D (NOLOCK) ON C.CPGCOD = D.CPGCOD

	WHERE 
		id = @ID

--	select * from #OrcamentoAux
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os enderecos de entrega do cliente

	IF object_id('tempdb.dbo.#ENDERECOS') IS NOT NULL
		DROP TABLE #ENDERECOS;

	SELECT 
		A.CLICOD, 
		A.CLIENDCOD,
		CLILOG,
		CLIENDNUM,		
		CLIENDBAI,
		RTRIM(LTRIM((SELECT MUNNOM FROM TBS003 C (NOLOCK) WHERE A.CLIENDMUNCOD = C.MUNCOD))) AS CLIENDMUNNOM,
		CLIENDUFE
	INTO #ENDERECOS FROM TBS0021 A (NOLOCK) 

	WHERE 
		CLIENDTIP = 'E' AND
		A.CLICOD = (SELECT TOP 1 CLICOD FROM #ORCAMENTOAUX)

--SELECT * FROM #ENDERECOS
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Dados do cliente

	IF OBJECT_ID('tempdb.dbo.#CLIENTE') IS NOT NULL
		DROP TABLE #CLIENTE;

	select 
	A.CLICOD,
	CLINOM,
	IIF(RTRIM(CLICGC) = '', '', dbo.FormatarCnpj(CLICGC)) AS CLICGC,
	IIF(RTRIM(CLICPF) = '', '', dbo.FormatarCnpj(CLICPF)) AS CLICPF,
	CLIEND,
	CLINUM,
	CLIBAI,
	(SELECT MUNNOM FROM TBS003 B (NOLOCK) WHERE A.MUNCOD = B.MUNCOD) AS MUNNON,
	A.UFESIG

	INTO #CLIENTE FROM TBS002 A (NOLOCK) 

	WHERE
		A.CLICOD = (SELECT TOP 1 CLICOD FROM #ORCAMENTOAUX)

--	select * FROM #CLIENTE
------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	IF OBJECT_ID('tempdb.dbo.#ORCAMENTO') IS NOT NULL
		DROP TABLE #ORCAMENTO;

	SELECT
		A.*,
		CLINOM,
		CLICGC,
		CLICPF,
		RTRIM(VENNOM) AS VENNOM ,
		RTRIM(V.VENEMAIL) AS VENEMAIL ,
		RTRIM(V.VENRAM) AS VENRAM,
		RTRIM(V.VENTEL) AS VENTEL,
		RTRIM(V.VENTEL2) AS VENTEL2,
		RTRIM(V.VENRAM2) AS VENRAM2,
		ISNULL(CLILOG, CLIEND) AS CLIEND,
		ISNULL(CLIENDNUM, CLINUM) AS CLINUM,
		ISNULL(CLIENDBAI, CLIBAI) AS CLIBAI,
		ISNULL(CLIENDMUNNOM, MUNNON) AS MUNNON,
		ISNULL(CLIENDUFE, UFESIG) AS UFESIG
				
	INTO #ORCAMENTO	FROM #ORCAMENTOAUX AS A
		JOIN #CLIENTE AS B ON A.CLICOD = B.CLICOD
		LEFT JOIN #ENDERECOS ON CLIENDCOD = ORCENDENTCOD
		LEFT JOIN TBS004 V ON A.VENCOD = V.VENCOD

------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Faz o refinamento da tabela para definir qual empresa e a vencedora, pelo menor valor
	-- utilizamos a tecnica "UNPIVOT", que transforma colunas em linhas
	;WITH
	totais_empresa AS (
		SELECT id, empresa, total
		FROM (
			SELECT id, total_tanby, total_misaspel, total_bestbag, total_papelyna, total_winpack
			FROM orca_esc
			where id = @ID
		) p
		UNPIVOT
		(
			total FOR empresa IN (total_tanby, total_misaspel, total_bestbag, total_papelyna, total_winpack)
		) AS unpvt
	),
	empresa_vencedora AS(
		SELECT TOP 1 
			empresa, 
			total
		FROM totais_empresa
		
		WHERE 
			total > 0

		ORDER BY
			total
	)
	SELECT 
		A.*,
		
		IIF(empresa = 'total_tanby', 'TM', 
		IIF(empresa = 'total_papelyna', 'PY',
		IIF(empresa = 'total_misaspel', 'MI',
		IIF(empresa = 'total_bestbag', 'BB',
		IIF(empresa = 'total_winpack', 'WP',''))))) AS vencedora
	FROM #ORCAMENTO A, empresa_vencedora B
	
	ORDER BY 
		item

------------------------------------------------------------------------------------------------------------------------------------------------------

End