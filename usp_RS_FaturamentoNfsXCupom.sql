/*
====================================================================================================================================================================================
WREL054 - Faturamento NFS X CUPOM
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
03/10/2025 WILLIAM
	- Correcao ao contabilizar quantidade de cupons por dia, levando em consideracao numero de cupom iguais em caixas diferentes;
24/04/2025 WILLIAM
	- Uso da SP "usp_Get_DiasUteis" em vez da "usp_GetDiasUteis";
06/03/2025 WILLIAM
	- Retirada dos atributos QTDCUPTOT e VALCUPTOT da tabela final;
05/03/2025 WILLIAM
	- Udo da SP "usp_Get_DWVendas" e usp_Get_DWDevolucaoVendas, para obter as informacoes de vendas e devolucao de vendas, respectivamente;
	- Alteracao do tipo de dados e nome do parm. @GRUPO int => @pGrupoBMPT char(1), pois no RS sera alterado para os valores (S/N);
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
17/12/2024 - WILLIAM
	- Leitura do parametro 1136, para saber se empresa tem frente de loja, se tiver, o valor sera o CNPJ da empresa, que sera comparada com o CNPJ da TBS023;
16/12/2024 - WILLIAM
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Alteracao nos parametros da chamada da SP "usp_ClientesGrupo", passando o codigo da empresa @codigoEmpresa;
	- Uso da SP "usp_DiasUteis" em vez da funcao "FCNDIASUTEIS"
====================================================================================================================================================================================
*/
--ALTER PROCEDURE [dbo].[usp_RS_FaturamentoNfsXCupom_DEBUG]
ALTER PROCEDURE [dbo].[usp_RS_FaturamentoNfsXCupom]
	@empcod smallint,
	@dataDe date = null,
	@dataAte date = null,
	@DIAS VARCHAR(50) = '',
	@pGrupoBMPT char(1) = 'S' 
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	DECLARE	@codigoEmpresa smallint, @data_De date, @data_Ate date, @DIASSEMANA varchar(50), @GrupoBMPT char(1),
			@contabiliza varchar(10), @qtdFeriados int, @qtdDiasUteis int, @ufEmpresaLocal char(2), @munEmpresaLocal int;

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod
	SET @data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));
	SET @DIASSEMANA = @DIAS;
	SET @GrupoBMPT = UPPER(@pGrupoBMPT);	

-- Atribuicoes internas
	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C,L', '');	

-- Obtem dias uteis da nova tabela de FERIADOS
	SELECT @ufEmpresaLocal = EMPUFESIG, @munEmpresaLocal = EMPMUNCOD FROM TBS023 (NOLOCK) WHERE EMPCOD = @codigoEmpresa;

	EXEC usp_Get_DiasUteis @ufEmpresaLocal, @munEmpresaLocal, @data_De, @data_Ate, '1', 'S', @qtdDiasUteis output, @qtdFeriados output		

-- Uso da funcao fSplit(), para as clausulas IN(), dos parametros multi-valores
-- UFs	
	IF OBJECT_ID('tempdb.dbo.#MV_DIASSEMANA') IS NOT NULL
		DROP TABLE #MV_DIASSEMANA;
	SELECT 
		elemento as valor
	INTO #MV_DIASSEMANA FROM fSplit(@DIASSEMANA, ',');

/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcontabiliza = @contabiliza

--	SELECT * FROM ##DWVendas;
/***********************************************************************************************************************************************************************************
	Obter as devolucoes de venda da tabela DWDevolucaoVenda
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as devolucoes do grupo, loja e corporativo
	
	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcontabiliza = @contabiliza	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utilizaremos CTE para contabilizar as vendas e devolucoes para cada grupo de vendas(Loja, corporativo e grupo BMPT)

;WITH 
	-- vendas de cupons
	vendascupons_caixa AS(
		SELECT 
			CASE DATEPART(w, data) 
				WHEN 1 THEN 'Dom'
				WHEN 2 THEN 'Seg'
				WHEN 3 THEN 'Ter'
				WHEN 4 THEN 'Qua'
				WHEN 5 THEN 'Qui' 
				WHEN 6 THEN 'Sex'
				WHEN 7 THEN 'Sab'
			END AS DIA,
			CONVERT(CHAR(10), data, 102) AS DATA,
			CONVERT(CHAR(10), data, 103) AS DATEMICUP,
			SUM(valorTotal) AS VALCUP, 
			COUNT(numeroDocumento) AS QTDCUP
		FROM ##DWVendas
		WHERE 
			caixa > 0
		GROUP BY
			data, 
			numeroDocumento,
			caixa
	),
	vendascupons AS(
		SELECT
			DIA,
			DATA,
			DATEMICUP,
			SUM(VALCUP) AS VALCUP,
			COUNT(DATEMICUP) AS QTDCUP
		FROM vendascupons_caixa
		GROUP BY
			DIA,
			DATA,
			DATEMICUP
	),
	-- vendas de cupons que geraram nota(nao é mais somado com o valor dos cupons, pois e um espelho do cupom)
	vendasnotascupons AS(
		SELECT 
			CASE DATEPART(w, data) 
				WHEN 1 THEN 'Dom'
				WHEN 2 THEN 'Seg'
				WHEN 3 THEN 'Ter'
				WHEN 4 THEN 'Qua'
				WHEN 5 THEN 'Qui' 
				WHEN 6 THEN 'Sex'
				WHEN 7 THEN 'Sab'
			END AS DIA,
			CONVERT(CHAR(10), data, 102) AS DATA,
			CONVERT(CHAR(10), data, 103) AS NFSDATEMICUP,
			SUM(valorTotal)AS NFSVALCUP, 
			COUNT(DISTINCT numeroDocumento) AS QTDNOTCUP
		FROM ##DWVendas
		WHERE 
			contabiliza = 'L' AND
			documentoReferenciado <> ''
		GROUP BY
			data
	),
	-- vendas do corporativo
	vendascorp AS(
		SELECT 
			CASE DATEPART(w, data) 
				WHEN 1 THEN 'Dom'
				WHEN 2 THEN 'Seg'
				WHEN 3 THEN 'Ter'
				WHEN 4 THEN 'Qua'
				WHEN 5 THEN 'Qui' 
				WHEN 6 THEN 'Sex'
				WHEN 7 THEN 'Sab'
			END AS DIA,
			CONVERT(CHAR(10), data, 102) AS DATA,
			CONVERT(CHAR(10), data, 103) AS NFSDATEMI,
			SUM(valorTotal) AS NFSVAL, 
			COUNT(DISTINCT numeroDocumento) AS QTDNOT
		FROM ##DWVendas

		WHERE 
			contabiliza <> 'G' AND
			caixa = 0 AND
			documentoReferenciado = ''
		GROUP BY
			data
	),
	-- devolucao de vendas do corporativo e loja
	devvendas AS(
		SELECT 
			CASE DATEPART(w, data) 
				WHEN 1 THEN 'Dom'
				WHEN 2 THEN 'Seg'
				WHEN 3 THEN 'Ter'
				WHEN 4 THEN 'Qua'
				WHEN 5 THEN 'Qui' 
				WHEN 6 THEN 'Sex'
				WHEN 7 THEN 'Sab'
			END AS DIA,
			CONVERT(CHAR(10), data, 102) AS DATA,
			CONVERT(CHAR(10), data, 103) AS NFEDATEFE,
			SUM(valorTotal) AS VALDEV, 
			COUNT(DISTINCT numeroDocumento) AS QTDNOTDEV
		FROM ##DWDevolucaoVendas

		WHERE 
			contabiliza <> 'G'
		GROUP BY
			data
	),
	-- vendas das empresas do grupo
	vendasgrupo AS(
		SELECT 
			CASE DATEPART(w, data) 
				WHEN 1 THEN 'Dom'
				WHEN 2 THEN 'Seg'
				WHEN 3 THEN 'Ter'
				WHEN 4 THEN 'Qua'
				WHEN 5 THEN 'Qui' 
				WHEN 6 THEN 'Sex'
				WHEN 7 THEN 'Sab'
			END AS DIA,
			CONVERT(CHAR(10), data, 102) AS DATA,
			CONVERT(CHAR(10), data, 103) AS NFSDATEMIGRU,
			SUM(valorTotal)AS NFSVALGRU, 
			COUNT(DISTINCT numeroDocumento) AS QTDNOTGRU
		FROM ##DWVendas

		WHERE 
			contabiliza = 'G' AND
			documentoReferenciado = ''
		GROUP BY
			data
	),
	-- devolucao de vendas das empresas do grupo
	devvendasgrupo AS(
		SELECT 
			CASE DATEPART(w, data) 
				WHEN 1 THEN 'Dom'
				WHEN 2 THEN 'Seg'
				WHEN 3 THEN 'Ter'
				WHEN 4 THEN 'Qua'
				WHEN 5 THEN 'Qui' 
				WHEN 6 THEN 'Sex'
				WHEN 7 THEN 'Sab'
			END AS DIA,
			CONVERT(CHAR(10), data, 102) AS DATA,
			CONVERT(CHAR(10), data, 103) AS NFEDATEFEGRU,
			SUM(valorTotal) AS VALDEVGRU, 
			COUNT(DISTINCT numeroDocumento) AS QTDNOTDEVGRU
		FROM ##DWDevolucaoVendas

		WHERE 
			contabiliza = 'G'
		GROUP BY
			data
	),
	-- Cria uma tabela com as datas dos movimentos de vendas e devolucao
	datasvendas AS(
		SELECT DISTINCT NFSDATEMI, DATA, DIA FROM vendascorp
		UNION
		SELECT DISTINCT NFSDATEMICUP, DATA, DIA FROM vendasnotascupons
		UNION
		SELECT DISTINCT DATEMICUP, DATA, DIA FROM vendascupons
		UNION
		SELECT DISTINCT NFSDATEMIGRU, DATA, DIA FROM vendasgrupo
		UNION
		SELECT DISTINCT NFEDATEFE, DATA, DIA FROM devvendas
		UNION
		SELECT DISTINCT NFEDATEFEGRU, DATA, DIA FROM devvendasgrupo
	)
	-- Tabela final do CTE
	SELECT 
		@qtdDiasUteis AS UTEL,
		Z.NFSDATEMI,
		Z.DIA ,
		ISNULL(D.QTDNOTGRU, 0) AS QTDNOTGRU,
		ISNULL(D.NFSVALGRU, 0) AS NFSVALGRU,
		ISNULL(A.QTDNOT, 0) AS QTDNOT,
		ISNULL(A.NFSVAL, 0) AS NFSVAL,
		ISNULL(A.QTDNOT, 0) + ISNULL(D.QTDNOTGRU, 0) AS QTDNOTTOT,
		ISNULL(A.NFSVAL, 0) + ISNULL(D.NFSVALGRU, 0) AS NFSVALTOT,

		ISNULL(B.QTDNOTCUP, 0) AS QTDNOTCUP,
		ISNULL(B.NFSVALCUP, 0) AS NFSVALCUP,
		ISNULL(C.QTDCUP, 0) AS QTDCUP,
		ISNULL(C.VALCUP, 0) AS VALCUP,

		ISNULL(F.QTDNOTDEVGRU, 0) AS QTDNOTDEVGRU,
		ISNULL(F.VALDEVGRU, 0) AS VALDEVGRU,
		ISNULL(E.QTDNOTDEV, 0) AS QTDNOTDEV,
		ISNULL(E.VALDEV, 0) AS VALDEV,
		ISNULL(E.QTDNOTDEV, 0) + ISNULL(F.QTDNOTDEVGRU, 0) AS QTDNOTDEVTOT,
		ISNULL(E.VALDEV, 0) + ISNULL(F.VALDEVGRU, 0) AS VALDEVTOT,

		ISNULL(D.NFSVALGRU,0) + ISNULL(A.NFSVAL, 0) + ISNULL(C.VALCUP,0) AS VALBRU,
		ISNULL(D.NFSVALGRU, 0) + ISNULL(A.NFSVAL, 0) + ISNULL(C.VALCUP, 0) - ISNULL(E.VALDEV,0) - ISNULL(F.VALDEVGRU,0) AS VALLIQ,
		ISNULL(A.NFSVAL,0) + ISNULL(C.VALCUP,0) - ISNULL(E.VALDEV,0) AS VALLIQSEMGRU

	FROM datasvendas Z
		LEFT JOIN vendascorp A ON Z.NFSDATEMI = A.NFSDATEMI
		LEFT JOIN vendasnotascupons B ON Z.NFSDATEMI = B.NFSDATEMICUP
		LEFT JOIN vendascupons C ON Z.NFSDATEMI = C.DATEMICUP
		LEFT JOIN vendasgrupo D ON Z.NFSDATEMI = D.NFSDATEMIGRU
		LEFT JOIN devvendas E ON Z.NFSDATEMI = E.NFEDATEFE
		LEFT JOIN devvendasgrupo F ON Z.NFSDATEMI = F.NFEDATEFEGRU
	WHERE 
		Z.DIA COLLATE DATABASE_DEFAULT IN (SELECT valor FROM #MV_DIASSEMANA)

	ORDER BY 
		Z.DATA
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END