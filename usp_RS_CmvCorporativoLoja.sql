/*
====================================================================================================================================================================================
WREL112 - CMV CORPORATIVO E LOJA
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
08/09/25 WILLIAM
- Inclusao da clausula "ORDER BY DATA DESC, EMPPRESA" no select da tabela SALDOINICIAL, para evitar variações no custo devido duplicão de valor no mesmo mês;
05/09/25 WILLIAM
	- Ajustes para realizar o calculo do lucro mesmo quando nao tiver vendas, quando há devoluçao;
03/09/25 WILLIAM
	- Alteracoes para obter o valor de custo, subtraindo o valor da devolucao do valor da venda;		
29/08/25 WILLIAM
	- Alteracoes para obter o preco de custo da tabela SALDOINICIAL ou da POLITICA DE PRECOS;	
28/03/25 WILLIAM
	- Uso da funcao ufn_Get_TemFrenteLoja(), para saber se empresa tem frente de loja;
	- Retirada da SP "usp_movcaixa", pois os dados foram unificados para o "usp_movcaixagz";	
17/12/2024 - WILLIAM
	- Leitura do parametro 1136, para saber se empresa tem frente de loja, se tiver, o valor sera o CNPJ da empresa, que sera comparada com o CNPJ da TBS023;
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Alteracao nos parametros da chamada da SP "usp_ClientesGrupo", passando o codigo da empresa @codigoEmpresa;
************************************************************************************************************************************************************************************
*/
-- ALTER PROCEDURE [dbo].[usp_RS_CmvCorporativoLoja_DEBUG]
ALTER PROCEDURE [dbo].[usp_RS_CmvCorporativoLoja]
	@empcod smallint,
	@dataDe date, 
	@dataAte date, 
	@codigoProduto CHAR(15) = '', 
	@descricaoProduto CHAR (60) = '',
	@codigoMarca int = 0, 
	@nomeMarca CHAR(60) = '',
	@pGrupoBMPT char(1) = 'S'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @data_De date, @data_Ate date, @PROCOD varchar(15), @PRODES varchar(60), @MARCOD int, @MARNOM varchar(60), @GrupoBMPT char(1),
			@contabiliza varchar(10),
			@empresaTBS010 smallint, @empresaTBS012 smallint;

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;		
	SET @data_De = @dataDe
	SET @data_Ate = @dataAte
	SET @PROCOD = @codigoProduto;
	SET @PRODES = @descricaoProduto;
	SET @MARCOD = @codigoMarca;
	SET @MARNOM = @nomeMarca;
	SET @GrupoBMPT = @pGrupoBMPT;

-- Atribuicoes internas	

	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C,L', '');	

-- Verificar se a tabela compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS012', @empresaTBS012 output;	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem codigos todos os produtos cadastrados, conforme os filtros;	

	IF OBJECT_ID('tempdb.dbo.#CODIGOSPRO') IS NOT NULL	
		DROP TABLE #CODIGOSPRO;

	CREATE TABLE #CODIGOSPRO(PROCOD varchar(15));

	INSERT INTO #CODIGOSPRO
	EXEC usp_Get_CodigosProdutos @codigoempresa, @PROCOD, @PRODES, @MARCOD, @MARNOM

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Refinamento dos produtos
	IF OBJECT_ID('tempdb.dbo.#TBS010') IS NOT NULL	
		DROP TABLE #TBS010;

	SELECT 
		A.PROCOD,
		PRODES,
		CASE WHEN len(A.MARCOD) = 4 
			then rtrim(A.MARCOD) + ' - ' + rtrim(A.MARNOM) 
			else right(('00' + ltrim(str(A.MARCOD))),3) + ' - ' + rtrim(A.MARNOM) 
		end as 'MARCA',
		PROUM1,
		ISNULL(rtrim(E.GRUDES),'')+' ('+ISNULL(Ltrim(str(E.GRUCOD,3)),0)+')' as GRUPO,
		ISNULL(rtrim(F.SUBGRUDES),'')+' ('+ISNULL(Ltrim(str(F.SUBGRUCOD,3)),0)+')' as SUBGRUPO -- 'subgrupo',

	INTO #TBS010 FROM TBS010 A (NOLOCK) 
		INNER JOIN #CODIGOSPRO P ON P.PROCOD COLLATE DATABASE_DEFAULT = A.PROCOD
		LEFT JOIN TBS012 E (NOLOCK) ON A.GRUCOD = E.GRUCOD
		LEFT JOIN TBS0121 F (NOLOCK) ON A.GRUCOD = F.GRUCOD AND A.SUBGRUCOD = F.SUBGRUCOD

	WHERE 
		PROEMPCOD = @empresaTBS010
		AND A.GRUEMPCOD = @empresaTBS012

--	SELECT * FROM #TBS010 order by PROCOD;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Cria tabela de datas para contabilizar vendas por ano e mes
	IF OBJECT_ID('tempdb.dbo.#DATAS') IS NOT NULL	
		DROP TABLE #DATAS;

	SELECT
		DISTINCT CONVERT(CHAR(7), DATEADD(DAY, number + 1, @data_De), 102) AS MES

	INTO #DATAS FROM master..spt_values

	WHERE
		type = 'P' AND 
		DATEADD(DAY, number + 1, @data_De) <= @data_Ate

	UNION 
	SELECT
		CONVERT(CHAR(7), @data_De, 102) AS MES

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Cria tabela de custos
	IF OBJECT_ID('tempdb.dbo.#CUSTOMEDIO') IS NOT NULL	
		DROP TABLE #CUSTOMEDIO;

	SELECT 
		ROW_NUMBER() OVER( PARTITION BY CODIGO  ORDER BY CODIGO, DATA DESC ) AS RANK,
		CONVERT(CHAR(7), DATEADD(DAY, -1, DATA), 102) AS MES,
		CODIGO AS SINPROCOD,
		CUSTO AS SINCUSAQU,
		EMPRESA

	INTO #CUSTOMEDIO FROM SALDOINICIAL A (NOLOCK)
		INNER JOIN #TBS010 ON PROCOD = CODIGO

	WHERE 
		CONVERT(CHAR(7), DATEADD(DAY, -1, DATA), 102) <= CONVERT(CHAR(7), @data_Ate, 102) 
		AND	ISNULL(CUSTO, 0) > 0 	
	ORDER BY 
		DATA DESC, 
		EMPRESA

	-- Apagar todos os valores com RANK > 1 e mes menor que @dataDe, pois sobrar� um valor para cada item de cada mes que foi filtrado, ou o primeiro valor antes da @dataDe
	DELETE #CUSTOMEDIO

	WHERE
		RANK > 1 AND
		MES < CONVERT(CHAR(7), @data_De, 102)

/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoMarca = @MARCOD,
		@pnomeMarca = @MARNOM,		
		@pcontabiliza = @contabiliza

/***********************************************************************************************************************************************************************************
	Obter as devolucoes de venda da tabela DWDevolucaoVenda
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as devolucoes do grupo, loja e corporativo
	
	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoMarca = @MARCOD,
		@pnomeMarca = @MARNOM,		
		@pcontabiliza = @contabiliza	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utilizaremos CTE para contabilizar as vendas e devolucoes para cada grupo de vendas(Loja, corporativo e grupo BMPT)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	;WITH	
		-- Obtem produtos unicos dos que realmente foram vendidos ou devolvidos,
		-- como base paraa tabela unificada de vendas e devolucao
		produtos_distinct AS(
			SELECT
				DISTINCT codigoProduto
			FROM ##DWVendas
			UNION
			SELECT
				DISTINCT codigoProduto
			FROM ##DWDevolucaoVendas			
		),		
		-- Faz o refinamento dos produtos
		produtos AS(
			SELECT 
				T.*
			FROM produtos_distinct
				INNER JOIN #TBS010 T ON PROCOD = codigoProduto
		),

		produtos_datas AS(
			SELECT 
				MES,
				P.* 
			FROM produtos P, #DATAS
		),

		-- Obtem custo dos produtos
		produtos_datas_custos AS(
			SELECT
				A.*,
				CONVERT(decimal(12,4),
				ISNULL(
				ISNULL((SELECT TOP 1 SINCUSAQU FROM #CUSTOMEDIO F (NOLOCK) WHERE A.PROCOD = F.SINPROCOD AND A.MES >= F.MES ORDER BY F.MES DESC),
				(SELECT TOP 1 SINCUSAQU FROM #CUSTOMEDIO K (NOLOCK) WHERE A.PROCOD = K.SINPROCOD ORDER BY K.SINPROCOD, K.MES)),
				ISNULL(dbo.CustoPolitica(GETDATE(), A.PROCOD), 0)
				)) AS SINCUSAQU,
				CASE WHEN (SELECT TOP 1 SINCUSAQU FROM #CUSTOMEDIO F (NOLOCK) WHERE A.PROCOD = F.SINPROCOD ORDER BY F.MES DESC) IS NULL
					THEN 'Politica'
					ELSE 'Custo Medio'
				END
				AS PRECO,				
				
				ISNULL(
				ISNULL((SELECT TOP 1 EMPRESA FROM #CUSTOMEDIO F (NOLOCK) WHERE A.PROCOD = F.SINPROCOD AND A.MES >= F.MES ORDER BY F.MES DESC),
				(SELECT TOP 1 EMPRESA FROM #CUSTOMEDIO K (NOLOCK) WHERE A.PROCOD = K.SINPROCOD ORDER BY K.SINPROCOD, K.MES)),
				''
				) AS EMPRESA

			FROM produtos_datas A
		),		
		-- vendas da loja
		vendas_loja AS(
			SELECT 
				CONVERT(CHAR(7), data, 102) AS MES,
				codigoProduto,
				valorTotal,
				quantidade
			FROM ##DWVendas
			WHERE 
				contabiliza = 'L'
				AND documentoReferenciado = ''
		),
		vendas_loja_agrupadas AS(
			SELECT 
				MES,
				codigoProduto,
				SUM(valorTotal) AS valorTotal,
				SUM(quantidade) AS quantidade
			FROM vendas_loja

			GROUP BY 
				MES,
				codigoProduto
		),
		-- Devolucoes da loja
		devolucoes_loja AS(
			SELECT 
				CONVERT(CHAR(7), data, 102) AS MES,
				codigoProduto,
				valorTotal,
				quantidade						
			FROM ##DWDevolucaoVendas
			WHERE 
				contabiliza = 'L'
		),
		devolucoes_loja_agrupadas AS(
			SELECT 
				MES,
				codigoProduto,
				SUM(valorTotal) AS valorTotal,
				SUM(quantidade) AS quantidade
			FROM devolucoes_loja

			GROUP BY 
				MES,
				codigoProduto
		),
		-- vendas do corporativo
		vendas_corp AS(
			SELECT 
				CONVERT(CHAR(7), data, 102) AS MES,
				codigoProduto,
				valorTotal,
				quantidade				
			FROM ##DWVendas
			WHERE 
				contabiliza = 'C'
				AND documentoReferenciado = ''
		),
		vendas_corp_agrupadas AS(
			SELECT 
				MES,
				codigoProduto,
				SUM(valorTotal) AS valorTotal,
				SUM(quantidade) AS quantidade
			FROM vendas_corp

			GROUP BY 
				MES,
				codigoProduto
		),
		--  Devoluções do corporativo
		devolucoes_corp AS(
			SELECT 
				CONVERT(CHAR(7), data, 102) AS MES,
				codigoProduto,
				valorTotal,
				quantidade				
			FROM ##DWDevolucaoVendas
			WHERE 
				contabiliza = 'C'
		),
		devolucoes_corp_agrupadas AS(
			SELECT 
				MES,
				codigoProduto,
				SUM(valorTotal) AS valorTotal,
				SUM(quantidade) AS quantidade
			FROM devolucoes_corp

			GROUP BY 
				MES,
				codigoProduto
		),	
		-- Vendas do grupo BMPT
		vendas_grupo AS(
			SELECT 
				CONVERT(CHAR(7), data, 102) AS MES,
				codigoProduto,
				valorTotal,
				quantidade	
			FROM ##DWVendas
			WHERE 
				contabiliza = 'G'
				AND documentoReferenciado = ''
		),
		vendas_grupo_agrupadas AS(
			SELECT 
				MES,
				codigoProduto,
				SUM(valorTotal) AS valorTotal,
				SUM(quantidade) AS quantidade
			FROM vendas_grupo

			GROUP BY 
				MES,
				codigoProduto
		),
		-- Devolucoes da corporativo
		devolucoes_grupo AS(
			SELECT 
				CONVERT(CHAR(7), data, 102) AS MES,
				codigoProduto,
				valorTotal,
				quantidade
			FROM ##DWDevolucaoVendas
			WHERE 
				contabiliza = 'G'
		),
		devolucoes_grupo_agrupadas AS(
			SELECT 
				MES,
				codigoProduto,
				SUM(valorTotal) AS valorTotal,
				SUM(quantidade) AS quantidade
			FROM devolucoes_grupo

			GROUP BY 
				MES,
				codigoProduto
		),		
		-- Junta os dados de vendas e devolucoes dos 3 grupos(loja, corporativo e grupo)
		vendas_devolucoes AS (
			SELECT
				P.MES,
				PROCOD,
				PRODES,
				MARCA,
				PROUM1,
				GRUPO AS [grupo],
				SUBGRUPO AS [subgrupo],

				-- Vendas
				-- Loja
				ISNULL(VL.valorTotal, 0) AS valorTotal_LOJ,
				ISNULL(VL.quantidade, 0) AS quantidade_LOJ,
				ROUND(ISNULL(SINCUSAQU, 0) * (ISNULL(VL.quantidade, 0) - ISNULL(DL.quantidade, 0)), 2) AS custo_LOJ,

				-- Corporativo
				ISNULL(VC.valorTotal, 0) AS valorTotal_COR,
				ISNULL(VC.quantidade, 0) AS quantidade_COR,
				ROUND(SINCUSAQU * (ISNULL(VC.quantidade, 0) - ISNULL(DC.quantidade, 0)), 2) AS custo_COR,

				-- Grupo
				ISNULL(VG.valorTotal, 0) AS valorTotal_GRU,
				ISNULL(VG.quantidade, 0) AS quantidade_GRU,				
				ROUND(ISNULL(SINCUSAQU, 0) * (ISNULL(VG.quantidade, 0) - ISNULL(DG.quantidade, 0)), 2) AS custo_GRU,

				-- Devolucoes
				-- Loja
				ISNULL(DL.valorTotal, 0) AS valorTotalDEV_LOJ,
				ISNULL(DL.quantidade, 0) AS quantidadeDEV_LOJ,
				-- Corporativo
				ISNULL(DC.valorTotal, 0) AS valorTotalDEV_COR,
				ISNULL(DC.quantidade, 0) AS quantidadeDEV_COR,				
				-- Grupo
				ISNULL(DG.valorTotal, 0) AS valorTotalDEV_GRU,
				ISNULL(DG.quantidade, 0) AS quantidadeDEV_GRU,

				PRECO,

				SINCUSAQU

			FROM produtos_datas_custos P
				LEFT JOIN vendas_loja_agrupadas VL ON VL.codigoProduto = PROCOD AND VL.MES = P.MES
				LEFT JOIN vendas_corp_agrupadas VC ON VC.codigoProduto = PROCOD AND VC.MES = P.MES
				LEFT JOIN vendas_grupo_agrupadas VG ON VG.codigoProduto = PROCOD AND VG.MES = P.MES

				LEFT JOIN devolucoes_loja_agrupadas DL ON DL.codigoProduto = PROCOD AND DL.MES = P.MES
				LEFT JOIN devolucoes_corp_agrupadas DC ON DC.codigoProduto = PROCOD AND DC.MES = P.MES
				LEFT JOIN devolucoes_grupo_agrupadas DG ON DG.codigoProduto = PROCOD AND DG.MES = P.MES
		),	
		-- Refinamento da tabela, para calcular os precos medios e eliminar registros sem vendas e sem devolucoes
		vendas_devolucoes_refinada AS (
			SELECT
				MES,
				PROCOD,
				PRODES,
				MARCA,
				PROUM1,
				grupo,
				subgrupo,
				-- Vendas
				-- Loja
				quantidade_LOJ AS LOJQTDVEN,
				valorTotal_LOJ AS LOJVALVEN,
				custo_LOJ AS TOTCUSLOJ,
				IIF(quantidade_LOJ = 0,
					0,
					ROUND(valorTotal_LOJ / quantidade_LOJ, 2)
				) AS LOJPREMED,
				SINCUSAQU AS PRECUSLOJ,		 
				ROUND(valorTotal_LOJ - valorTotalDEV_LOJ - custo_LOJ, 2) AS LUCLOJ,

				-- Corporativo
				quantidade_COR AS NFSQTDVEN,
				valorTotal_COR AS NFSTOTITEST,				
				custo_COR AS TOTCUSCOR,
				IIF(quantidade_COR = 0,
					0,
					ROUND(valorTotal_COR / quantidade_COR, 2)
				) AS NFSPREMED,
				SINCUSAQU AS PRECUSCOR,
				ROUND(valorTotal_COR - valorTotalDEV_COR - custo_COR, 2) AS LUCCOR,

				-- Grupo
				quantidade_GRU AS NFSQTDVENGRU,				
				valorTotal_GRU AS NFSTOTITESTGRU,				
				custo_GRU AS TOTCUSGRU,
				IIF(quantidade_GRU = 0,
					0,
					ROUND(valorTotal_GRU / quantidade_GRU, 2)
				) AS NFSPREMEDGRU,	

				SINCUSAQU AS PRECUSGRU,		
				ROUND(valorTotal_GRU - valorTotalDEV_GRU - custo_GRU, 2) AS LUCGRU,	

				-- Devolucoes
				-- Loja
				quantidadeDEV_LOJ AS NFEQTDDEVLOJ,
				valorTotalDEV_LOJ AS NFETOTOPEITELOJ,
				IIF(quantidadeDEV_LOJ = 0,
					0,
					ROUND(valorTotalDEV_LOJ / quantidadeDEV_LOJ, 2)
				) AS NFEPREMEDLOJ,				
				
				-- Corporativo
				valorTotalDEV_COR AS NFETOTOPEITECOR,
				quantidadeDEV_COR AS NFEQTDDEVCOR,
				IIF(quantidadeDEV_COR = 0,
					0,
					ROUND(valorTotalDEV_COR / quantidadeDEV_COR, 2)
				) AS NFEPREMEDCOR,					
				
				-- Grupo
				quantidadeDEV_GRU AS NFEQTDDEVGRU,
				valorTotalDEV_GRU AS NFETOTOPEITEGRU,
				IIF(quantidadeDEV_GRU = 0,
					0,
					ROUND(valorTotalDEV_GRU / quantidadeDEV_GRU, 2)
				) AS NFEPREMEDGRU,

				PRECO
			
			FROM vendas_devolucoes

			WHERE 
				quantidade_LOJ <> 0
				OR quantidade_COR <> 0
				OR quantidade_GRU <> 0
				OR quantidadeDEV_LOJ <> 0
				OR quantidadeDEV_COR <> 0
				OR quantidadeDEV_GRU <> 0
		),
		tabela_final as(		
		-- Tabela final
		SELECT 
			MES,
			grupo,
			subgrupo,
			PROCOD,
			PRODES,
			MARCA,
			PROUM1,

			-- GRUPO
			NFSPREMEDGRU,
			NFSQTDVENGRU,
			NFSTOTITESTGRU,
			NFEPREMEDGRU,
			NFEQTDDEVGRU,
			NFETOTOPEITEGRU,
			PRECUSGRU,
			TOTCUSGRU,
			LUCGRU,

			-- CORPORATIVO
			NFSPREMED,
			NFSQTDVEN,
			NFSTOTITEST,
			NFEPREMEDCOR,
			NFEQTDDEVCOR,
			NFETOTOPEITECOR,
			PRECUSCOR,
			TOTCUSCOR,
			LUCCOR,

			-- LOJA
			LOJPREMED,
			LOJQTDVEN,
			LOJVALVEN,
			NFEPREMEDLOJ,
			NFEQTDDEVLOJ,
			NFETOTOPEITELOJ,
			PRECUSLOJ,
			TOTCUSLOJ,
			LUCLOJ,

			-- TOTAL
			NFSQTDVENGRU + NFSQTDVEN + LOJQTDVEN AS QTDVENTOT,
			LOJVALVEN + NFSTOTITEST + NFSTOTITESTGRU AS VALVENTOT,
			NFEQTDDEVCOR + NFEQTDDEVLOJ + NFEQTDDEVGRU AS QTDDEVTOT,
			NFETOTOPEITECOR + NFETOTOPEITELOJ + NFETOTOPEITEGRU AS VALDEVTOT,

			(TOTCUSGRU + TOTCUSCOR + TOTCUSLOJ) AS VALCUSTOT,
			PRECO,
			
			(LUCGRU + LUCCOR + LUCLOJ) AS VALLUCTOT

		FROM vendas_devolucoes_refinada
		)

		select * from tabela_final;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;	
/**/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
END