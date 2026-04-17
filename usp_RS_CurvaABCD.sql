/*
====================================================================================================================================================================================
WREL020 - Curva ABCD
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
17/04/2026 WILLIAM
	- Incluscao da clausula "COLLATE DATABASE_DEFAULT" no momente de criar as tabelas [#CODIGOSPRO] e, melhora a performance sem estar no "Where";
07/10/2025 WILLIAM
	- Inclusão de UPDATE para zerar a letra da curva no cadastro de produtos, antes de atualizar novamente;
02/10/2025 WILLIAM
	- Novo parametro para atualizar ou nao o cadastro do produto, com a letra da curva(A,B,C ou D), dessa forma podemos configurar a assinatura do RS que roda 
	diariamente nas empresas, a dar UPDATE na TBS010 somente nesse momento;
08/05/2025 WILLIAM
	- Retirada dos atributos PROLOCFIS, GRUPO e SUBGRUPO, a pedido da Edmarie, pois ela tem que excluir manualmente no Excel;
05/05/2025 WILLIAM
	- Udo da SP "usp_Get_DWVendas" e usp_Get_DWDevolucaoVendas, para obter as informacoes de vendas e devolucao de vendas, respectivamente, 
	deixando o codigo mais "limpo";
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes;
	- Retirada de codigo sem uso;
28/03/25 WILLIAM
	- Uso da funcao ufn_Get_TemFrenteLoja(), para saber se empresa tem frente de loja;
	- Retirada da SP "usp_movcaixa", pois os dados foram unificados para o "usp_movcaixagz";
03/02/2025 WILLIAM
	- Aplicar refinamento no codigo;
	- Uso da SP "usp_Get_DiasUteis";	
	- Uso da funcao "ufn_Get_Parametro" e "ufn_Get_TemFrenteLoja";
	- Uso da SP "usp_Get_CodigosProdutos";
	- Filtro por empresa de tabelas, via SP "usp_GetCodigoEmpresaTabela";
06/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Uso da SP "usp_ClientesGrupo" para obter a lista de clientes do grupo BMPT;	
	- Uso da SP "sp_movcaixa" pela "usp_movcaixa";
	- Uso da SP "sp_movcaixagz" pela "usp_movcaixagz";
	- Uso da SP "usp_DiasUteis" em vez da funcao "FCNDIASUTEIS"
	- Leitura do parametro 1136, para saber se empresa tem frente de loja, se tiver, o valor sera o CNPJ da empresa, que sera comparada com o CNPJ da TBS023;
========================================================================================================================================================================================================
*/
--ALTER PROC [dbo].[usp_RS_CurvaABCD_DEBUG]
ALTER PROC [dbo].[usp_RS_CurvaABCD]
	@empcod smallint,
	@data1de date = null,
	@data1ate date = null,
	@data2de date = null,
	@data2ate date = null,
	@data3de date = null,
	@data3ate date = null,
	@codigoMarca int = 0,
	@nomeMarca varchar(60) = '',
	@descricaoProduto varchar(60) = '',	
	@pA int = 80,
	@pB int = 95,
	@DIAS int = 25,
	@zeraQuantidadeRepor char(1) = 'N',
	@pGrupoBMPT char(1) = 'S',
	@pGravarCurvaProduto char(1) = ''
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @Data1_De date, @Data1_Ate date, @Data2_De date, @Data2_Ate date, @Data3_De date, @Data3_Ate date, @MARCOD int, @MARNOM varchar(60), @PRODES VARCHAR(60),
			@pCurvaA int, @pCurvaB int, @DiasReposicao int, @GrupoBMPT char(1), @zeraQtdRepor char(1), @DIA1 INT, @DIA2 INT, @DIA3 INT, @CNPJEmpresalocal char(14),
			@GravarCurvaProduto char(1),
			@ufEmpresaLocal char(2), @munEmpresaLocal int, @qtdFeriados int, @DiasUteis int, @UNIDADE VARCHAR(20), @VerificaFiltrosData varchar(4), @contabiliza char(10),
			@empresaTBS010 smallint, @empresaTBS012 smallint;

	-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Data1_De = @data1de;
	SET @Data1_Ate = @data1ate;
	SET @Data2_De = @data2de;
	SET @Data2_Ate = @data2ate;
	SET @Data3_De = @data3de;
	SET @Data3_Ate = @data3ate;
	SET @MARCOD = @codigoMarca;
	SET @MARNOM = @nomeMarca;
	SET @PRODES = @descricaoProduto;	
	SET @pCurvaA = @pA;
	SET @pCurvaB = @pB;
	SET @DiasReposicao = @DIAS;
	SET @GrupoBMPT = @pGrupoBMPT;
	SET @zeraQtdRepor = @zeraQuantidadeRepor;
	SET @GravarCurvaProduto = @pGravarCurvaProduto;

-- Atribuicoes gerais
	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C,L', '');

	SELECT @CNPJEmpresalocal = EMPCGC, @ufEmpresaLocal = EMPUFESIG, @munEmpresaLocal = EMPMUNCOD, @UNIDADE = RTRIM(LTRIM(EMPNOMFAN)) FROM TBS023 (NOLOCK) WHERE EMPCOD = @codigoEmpresa;

	SET @VerificaFiltrosData = (SELECT CASE WHEN @Data1_Ate < @Data3_Ate AND @Data2_Ate < @Data3_Ate AND @Data1_Ate < @Data2_Ate THEN 'OK' ELSE 'ERRO' END AS 'SELECT')

	-- Obtem dias uteis da nova tabela de FERIADOS
	EXEC usp_Get_DiasUteis @ufEmpresaLocal, @munEmpresaLocal, @Data1_De, @Data1_Ate, '1', 'S', @DIA1 output, @qtdFeriados output		
	EXEC usp_Get_DiasUteis @ufEmpresaLocal, @munEmpresaLocal, @Data2_De, @Data2_Ate, '1', 'S', @DIA2 output, @qtdFeriados output		
	EXEC usp_Get_DiasUteis @ufEmpresaLocal, @munEmpresaLocal, @Data3_De, @Data3_Ate, '1', 'S', @DIA3 output, @qtdFeriados output		

	SET @DiasUteis = @DIA1 + @DIA2 + @DIA3 	

-- Verificar se a tabela compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS012', @empresaTBS012 output;

	IF @VerificaFiltrosData = 'OK'
	BEGIN
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		-- Obtem codigos todos os produtos cadastrados, ja que teremos a classificacao "D", para produtos nao vendidos nos periodos
		-- Aplica filtros conforme parametros de entrada

		IF OBJECT_ID('tempdb.dbo.#CODIGOSPRO') IS NOT NULL	
			DROP TABLE #CODIGOSPRO;

		CREATE TABLE #CODIGOSPRO(
			PROCOD varchar(15) COLLATE DATABASE_DEFAULT
		);

		INSERT INTO #CODIGOSPRO
		EXEC usp_Get_CodigosProdutos @codigoempresa, '', @PRODES, @MARCOD, @MARNOM

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		-- Obtem os saldos dos produtos acima

		IF OBJECT_ID('tempdb.dbo.#SALDOS') IS NOT NULL
			DROP TABLE #SALDOS;

		SELECT 
			A.PROCOD,
			(SELECT ESTQTDATU - ESTQTDRES FROM TBS032 B (NOLOCK) WHERE PROEMPCOD = @empresaTBS010 AND ESTLOC = 1 AND A.PROCOD = B.PROCOD ) AS EST1,
			(SELECT ESTQTDATU - ESTQTDRES FROM TBS032 B (NOLOCK) WHERE PROEMPCOD = @empresaTBS010 AND ESTLOC = 2 AND A.PROCOD = B.PROCOD ) AS EST2,
			ISNULL(SUM(ESTQTDRES), 0) AS ESTQTDRES,
			ISNULL(SUM(ESTQTDCMP), 0) AS ESTQTDCMP,
			ISNULL(SUM(ESTQTDPEN), 0) AS ESTQTDPEN
		INTO #SALDOS FROM TBS032 A (NOLOCK)
			INNER JOIN #CODIGOSPRO P ON P.PROCOD = A.PROCOD

		WHERE 
			PROEMPCOD = @empresaTBS010 
			AND ESTLOC IN (1,2)
			AND (ESTQTDATU <> 0 OR ESTQTDPEN <> 0 OR ESTQTDCMP <> 0 )

		GROUP BY 
			A.PROCOD

		-- Refinamento dos produtos obtidos acima, obtendo marca, localizacao, descricao, UM, grupo e subgrupo

		IF OBJECT_ID('Tempdb.dbo.#TBS010') IS NOT NULL	
			DROP TABLE #TBS010;

		SELECT 
			A.PROSTATUS,
			A.PROCOD,
			A.PRODES,
			CASE WHEN len(A.MARCOD) = 4 
				then rtrim(A.MARCOD) + ' - ' + rtrim(A.MARNOM) 
				else right(('00' + ltrim(str(A.MARCOD))),3) + ' - ' + rtrim(A.MARNOM) 
			end as 'MARCA',
			PROUM1,

			-- Saldos
			ISNULL(EST1, 0) AS EST1,
			ISNULL(EST2, 0) AS EST2,
			ISNULL(ESTQTDRES, 0) AS ESTQTDRES,
			ISNULL(ESTQTDCMP, 0) AS ESTQTDCMP,
			ISNULL(ESTQTDPEN, 0) AS ESTQTDPEN,
			
			ISNULL(T.NFSQTD,0) AS QTDTRAN		-- Em transito

		INTO #TBS010 FROM TBS010 A (NOLOCK) 
			INNER JOIN #CODIGOSPRO P ON P.PROCOD = A.PROCOD
			LEFT JOIN #SALDOS S (NOLOCK) ON S.PROCOD = A.PROCOD
			LEFT JOIN ItensEmTransito T (NOLOCK) ON T.PROCOD = A.PROCOD
		WHERE 
			PROEMPCOD = @empresaTBS010 AND 
			A.GRUEMPCOD = @empresaTBS012

	--	SELECT * FROM #TBS010;
	/***********************************************************************************************************************************************************************************
		Obter as vendas da tabela DWVendas
	***********************************************************************************************************************************************************************************/	
		-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo
		-- Obtem as vendas "de/ate", onde "De" sera a primeira da ta do periodo 1, e "Ate", a segunda data do periodo 3;
		
		EXEC usp_Get_DWVendas
			@empcod = @codigoEmpresa,
			@pdataDe = @Data1_De,
			@pdataAte = @Data3_Ate,
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
			@pdataDe = @Data1_De,
			@pdataAte = @Data3_Ate,
			@pdescricaoProduto = @PRODES,
			@pcodigoMarca = @MARCOD,
			@pnomeMarca = @MARNOM,
			@pcontabiliza = @contabiliza

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		-- Cria tabelas temporarias para serem usados no final, devido ao erro ao somente usar CTE
		IF OBJECT_ID('tempdb.dbo.#ABC') IS NOT NULL
			DROP TABLE #ABC;

		IF OBJECT_ID('tempdb.dbo.#ABC_PORCENT') IS NOT NULL
			DROP TABLE #ABC_PORCENT;			

		IF OBJECT_ID('tempdb.dbo.#ABCD_COUNT_SUM') IS NOT NULL		
			DROP TABLE #ABCD_COUNT_SUM;

		IF OBJECT_ID('tempdb.dbo.#ABCD_FINAL') IS NOT NULL
			DROP TABLE #ABCD_FINAL;			

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		-- Utilizaremos CTE para contabilizar as vendas e devolucoes para cada grupo de vendas(Loja, corporativo e grupo BMPT)	
		;WITH 
			-- Obtem os produtos que foram vendidos independente do periodo
			 produtos AS (
			 	SELECT
			 		DISTINCT codigoProduto
			 	FROM ##DWVendas
			),	

			-- Classifica as vendas conforme periodo: 1, 2 ou 3		
			vendas_periodos AS (
				SELECT  
					IIF(data BETWEEN @Data1_De AND @Data1_Ate, 1, 
					IIF(data BETWEEN @Data2_De AND @Data2_Ate, 2, 3)) AS PERIODO,
					codigoProduto,
					quantidade,
					valorTotal,
					documentoReferenciado,
					contabiliza
				FROM ##DWVendas
			),
			-- Classifica as devolucoes conforme periodo: 1, 2 ou 3		
			devolucoes_periodos AS (
				SELECT  
					IIF(data BETWEEN @Data1_De AND @Data1_Ate, 1, 
					IIF(data BETWEEN @Data2_De AND @Data2_Ate, 2, 3)) AS PERIODO,
					codigoProduto,
					quantidade,
					valorTotal,
					documentoReferenciado,
					contabiliza
				FROM ##DWDevolucaoVendas
			),
			-- Vendas contabilizadas para a LOJA, agrupando por periodo e produdo
			vendas_loja AS (
				SELECT 
					PERIODO,
					codigoProduto,
					SUM(quantidade) AS quantidade,
					SUM(valorTotal) AS valorTotal
				FROM vendas_periodos

				WHERE 
					contabiliza = 'L' 
					AND documentoReferenciado = ''	-- isso ira pegar tanto cupom, quanto notas sem cupom que contabilizou para a loja

				GROUP BY
					PERIODO,
					codigoProduto
			),					
			-- devolucoes contabilizadas para a LOJA
			devolucao_loja AS (
				SELECT 
					PERIODO,
					codigoProduto,
					SUM(quantidade) AS quantidade,
					SUM(valorTotal) AS valorTotal				
				FROM devolucoes_periodos

				WHERE 
					contabiliza = 'L' 

				GROUP BY
					PERIODO,
					codigoProduto		
			),
			-- Vendas contabilizadas para o CORPORATIVO
			vendas_corp AS (
				SELECT 
					PERIODO,
					codigoProduto,
					SUM(quantidade) AS quantidade,
					SUM(valorTotal) AS valorTotal
				FROM vendas_periodos

				WHERE 
					contabiliza = 'C' 
					AND documentoReferenciado = ''	-- isso ira pegar tanto cupom, quanto notas sem cupom que contabilizou para a loja

				GROUP BY
					PERIODO,
					codigoProduto
			),
			-- devolucoes contabilizadas para a COPORATIVO
			devolucao_corp AS (
				SELECT 
					PERIODO,
					codigoProduto,
					SUM(quantidade) AS quantidade,
					SUM(valorTotal) AS valorTotal				
				FROM devolucoes_periodos

				WHERE 
					contabiliza = 'C' 

				GROUP BY
					PERIODO,
					codigoProduto
			),
			-- Vendas contabilizadas para o GRUPO			
			vendas_grupo AS (
				SELECT 
					PERIODO,
					codigoProduto,
					SUM(quantidade) AS quantidade,
					SUM(valorTotal) AS valorTotal
				FROM vendas_periodos

				WHERE 
					contabiliza = 'G' 
					AND documentoReferenciado = ''	-- isso ira pegar tanto cupom, quanto notas sem cupom que contabilizou para a loja

				GROUP BY
					PERIODO,
					codigoProduto
			),
			-- devolucoes contabilizadas para a COPORATIVO
			devolucao_grupo AS (
				SELECT 
					PERIODO,
					codigoProduto,
					SUM(quantidade) AS quantidade,
					SUM(valorTotal) AS valorTotal				
				FROM devolucoes_periodos

				WHERE 
					contabiliza = 'G' 

				GROUP BY
					PERIODO,
					codigoProduto
			),	
			-- Juntar as vendas e devolucoes do periodo 1
			vendas_devolucoes1 AS(
				SELECT
					p.codigoProduto,
					ISNULL(vl.quantidade, 0) AS quantidadeLoja1,
					ISNULL(vc.quantidade, 0) + ISNULL(vg.quantidade, 0) AS quantidadeCorp1,	-- quantidade coporativo = corp + grupo 
					ISNULL(vl.quantidade, 0) + ISNULL(vc.quantidade, 0) + ISNULL(vg.quantidade, 0) AS quantidadeTotal1,	-- quantidade total do periodo 1

					ISNULL(dl.quantidade, 0) + ISNULL(dc.quantidade, 0) + ISNULL(dg.quantidade, 0) AS quantidadeDev1,
					ISNULL(vl.valorTotal, 0) + ISNULL(vc.valorTotal, 0) + ISNULL(vg.valorTotal, 0) AS valorTotal1, 		
					ISNULL(dl.valorTotal, 0) + ISNULL(dc.valorTotal, 0) + ISNULL(dg.valorTotal, 0) AS valorTotalDev1

				FROM produtos p
					LEFT JOIN vendas_loja vl ON vl.PERIODO = 1 AND vl.codigoProduto = p.codigoProduto
					LEFT JOIN devolucao_loja dl ON dl.PERIODO = 1 AND dl.codigoProduto = p.codigoProduto
					LEFT JOIN vendas_corp vc ON vc.PERIODO = 1 AND vc.codigoProduto = p.codigoProduto
					LEFT JOIN devolucao_corp dc ON dc.PERIODO = 1 AND dc.codigoProduto = p.codigoProduto
					LEFT JOIN vendas_grupo vg ON vg.PERIODO = 1 AND vg.codigoProduto = p.codigoProduto
					LEFT JOIN devolucao_grupo dg ON dg.PERIODO = 1 AND dg.codigoProduto = p.codigoProduto
			),						
			-- Juntar as vendas e devolucoes do periodo 2
			vendas_devolucoes2 AS(
				SELECT
					p.codigoProduto,
					ISNULL(vl.quantidade, 0) AS quantidadeLoja2,
					ISNULL(vc.quantidade, 0) + ISNULL(vg.quantidade, 0) AS quantidadeCorp2,	-- quantidade coporativo = corp + grupo 
					ISNULL(vl.quantidade, 0) + ISNULL(vc.quantidade, 0) + ISNULL(vg.quantidade, 0) AS quantidadeTotal2,	-- quantidade total do periodo 2				

					ISNULL(dl.quantidade, 0) + ISNULL(dc.quantidade, 0) + ISNULL(dg.quantidade, 0) AS quantidadeDev2,
					ISNULL(vl.valorTotal, 0) + ISNULL(vc.valorTotal, 0) + ISNULL(vg.valorTotal, 0) AS valorTotal2, 		
					ISNULL(dl.valorTotal, 0) + ISNULL(dc.valorTotal, 0) + ISNULL(dg.valorTotal, 0) AS valorTotalDev2
					
				FROM produtos p
					LEFT JOIN vendas_loja vl ON vl.PERIODO = 2 AND vl.codigoProduto = p.codigoProduto
					LEFT JOIN devolucao_loja dl ON dl.PERIODO = 2 AND dl.codigoProduto = p.codigoProduto
					LEFT JOIN vendas_corp vc ON vc.PERIODO = 2 AND vc.codigoProduto = p.codigoProduto
					LEFT JOIN devolucao_corp dc ON dc.PERIODO = 2 AND dc.codigoProduto = p.codigoProduto
					LEFT JOIN vendas_grupo vg ON vg.PERIODO = 2 AND vg.codigoProduto = p.codigoProduto
					LEFT JOIN devolucao_grupo dg ON dg.PERIODO = 2 AND dg.codigoProduto = p.codigoProduto
			),			
			-- Juntar as vendas e devolucoes do periodo 3
			vendas_devolucoes3 AS(
				SELECT
					p.codigoProduto,
					ISNULL(vl.quantidade, 0) AS quantidadeLoja3,
					ISNULL(vc.quantidade, 0) + ISNULL(vg.quantidade, 0) AS quantidadeCorp3,	-- quantidade coporativo = corp + grupo 
					ISNULL(vl.quantidade, 0) + ISNULL(vc.quantidade, 0) + ISNULL(vg.quantidade, 0) AS quantidadeTotal3,	-- quantidade total do periodo 3 

					ISNULL(dl.quantidade, 0) + ISNULL(dc.quantidade, 0) + ISNULL(dg.quantidade, 0) AS quantidadeDev3,
					ISNULL(vl.valorTotal, 0) + ISNULL(vc.valorTotal, 0) + ISNULL(vg.valorTotal, 0) AS valorTotal3,	
					ISNULL(dl.valorTotal, 0) + ISNULL(dc.valorTotal, 0) + ISNULL(dg.valorTotal, 0) AS valorTotalDev3		

				FROM produtos p
					LEFT JOIN vendas_loja vl ON vl.PERIODO = 3 AND vl.codigoProduto = p.codigoProduto
					LEFT JOIN devolucao_loja dl ON dl.PERIODO = 3 AND dl.codigoProduto = p.codigoProduto
					LEFT JOIN vendas_corp vc ON vc.PERIODO = 3 AND vc.codigoProduto = p.codigoProduto
					LEFT JOIN devolucao_corp dc ON dc.PERIODO = 3 AND dc.codigoProduto = p.codigoProduto
					LEFT JOIN vendas_grupo vg ON vg.PERIODO = 3 AND vg.codigoProduto = p.codigoProduto
					LEFT JOIN devolucao_grupo dg ON dg.PERIODO = 3 AND dg.codigoProduto = p.codigoProduto
			),		
			-- Unifica vendas e devolucoes dos 3 periodos em 1 tabela
			vendas_devolucoes AS(
				SELECT
					p.codigoProduto,
					ISNULL(quantidadeLoja1, 0) AS quantidadeLoja1,
					ISNULL(quantidadeCorp1, 0) AS quantidadeCorp1,
					ISNULL(quantidadeDev1, 0) AS quantidadeDev1,
					ISNULL(valorTotal1, 0) AS valorTotal1,
					ISNULL(quantidadeTotal1, 0) AS quantidadeTotal1,	-- qtd. total do periodo 1

					ISNULL(quantidadeLoja2, 0) AS quantidadeLoja2,
					ISNULL(quantidadeCorp2, 0) AS quantidadeCorp2,
					ISNULL(quantidadeDev2, 0) AS quantidadeDev2,
					ISNULL(valorTotal2, 0) AS valorTotal2,
					ISNULL(quantidadeTotal2, 0) AS quantidadeTotal2,	-- qtd. total do periodo 2
					
					ISNULL(quantidadeLoja3, 0) AS quantidadeLoja3,
					ISNULL(quantidadeCorp3, 0) AS quantidadeCorp3,
					ISNULL(quantidadeDev3, 0) AS quantidadeDev3,
					ISNULL(valorTotal3, 0) AS valorTotal3,
					ISNULL(quantidadeTotal3, 0) AS quantidadeTotal3,	-- qtd. total do periodo 3

					-- Total geral do produto: quantidade e valor
					-- Vendas:
					ISNULL(quantidadeTotal1, 0) + ISNULL(quantidadeTotal2, 0) + ISNULL(quantidadeTotal3, 0) AS quantidadeTotal123,
					ISNULL(valorTotal1, 0) + ISNULL(valorTotal2, 0) + ISNULL(valorTotal3, 0) AS valorTotal123,
					-- Devolucao:
					ISNULL(quantidadeDev1, 0) + ISNULL(quantidadeDev2, 0) + ISNULL(quantidadeDev3, 0) AS quantidadeTotalDev123,
					ISNULL(valorTotalDev1, 0) + ISNULL(valorTotalDev2, 0) + ISNULL(valorTotalDev3, 0) AS valorTotalDev123

				FROM produtos p
					LEFT JOIN vendas_devolucoes1 v1 ON v1.codigoProduto = p.codigoProduto
					LEFT JOIN vendas_devolucoes2 v2 ON v2.codigoProduto = p.codigoProduto
					LEFT JOIN vendas_devolucoes3 v3 ON v3.codigoProduto = p.codigoProduto				
			),							
			-- Total geral de todos os produtos, para obter as porcentagens por produto e total geral
			valor_total AS (
				SELECT
					SUM(valorTotal123) AS VALOR
				FROM vendas_devolucoes
			)					
			-- ************************************************************************************************************************************************
			-- A partir desse ponto, deixamos de usar CTE, devido algumas limitacoes que ocorreram nos selects abaixo, ocasionando travamento 
			-- com mais de 5 minutos executando a SP sem finalizar, ocasionando TimerOut por parte do ReportServer
			-- ************************************************************************************************************************************************			

			-- Lista produtos ABC			
			SELECT 
				ROW_NUMBER() OVER (ORDER BY ISNULL(valorTotal123, 0) DESC) AS ordem,
				RTRIM(@UNIDADE) AS UNIDADE,
				PROSTATUS,
				PROCOD,
				PRODES,
				MARCA,
				PROUM1,
				ISNULL(EST1, 0) AS ESTOQUE,
				ISNULL(EST2, 0) AS LOJA,
				ISNULL(EST1, 0) + ISNULL(EST2, 0) AS ESTQTDDIS, -- n�o CONTABILIZAR O SALDO NEGATIVO DA LOJA COMO ZERO(0), solicitacao Elaine 09/05/2018
				ISNULL(ESTQTDRES, 0) AS ESTQTDRES,
				ISNULL(ESTQTDPEN, 0) AS ESTQTDPEN,
				ISNULL(ESTQTDCMP, 0) AS ESTQTDCMP,

				-- QUANTIDADE DE ITENS EM TRANSITO
				QTDTRAN,

				-- 1o PERIODO DE VENDAS: LOJA + CORPORATIVO + DEVOLUCAO
				ISNULL(quantidadeLoja1, 0) AS LOJAQTD1,
				ISNULL(quantidadeCorp1, 0) AS CORPQTD1,
				ISNULL(quantidadeTotal1, 0) AS VENQTDTOT1,			
				ISNULL(quantidadeDev1, 0) AS DEVQTD1,				

				-- 2o PERIODO DE VENDAS: LOJA + CORPORATIVO + DEVOLUCAO
				ISNULL(quantidadeLoja2, 0) AS LOJAQTD2,
				ISNULL(quantidadeCorp2, 0) AS CORPQTD2,
				ISNULL(quantidadeTotal2, 0) AS VENQTDTOT2,
				ISNULL(quantidadeDev2, 0) AS DEVQTD2,

				-- 3o PERIODO DE VENDAS: LOJA + CORPORATIVO + DEVOLUCAO
				ISNULL(quantidadeLoja3, 0) AS LOJAQTD3,
				ISNULL(quantidadeCorp3, 0) AS CORPQTD3,
				ISNULL(quantidadeTotal3, 0) AS VENQTDTOT3,
				ISNULL(quantidadeDev3, 0) AS DEVQTD3,

				-- QUANTIDADE total vendida do produto
				ISNULL(quantidadeTotal123, 0) AS VENQTDTOT,

				-- VALOR total vendida do produto
				ISNULL(valorTotal123, 0) AS VENVALTOT,

				-- QUANTIDADE total devolvido do produto
				ISNULL(quantidadeTotalDev123, 0) AS DEVQTDTOT,

				-- VALOR total devolvido do produto
				ISNULL(valorTotalDev123, 0) AS DEVVALTOT,

				-- dias uteis 
				@DIA1 AS DIA1,
				@DIA2 AS DIA2,
				@DIA3 AS DIA3,

				(SELECT VALOR FROM valor_total) AS VALOR,
		
				IIF((SELECT VALOR FROM valor_total) <= 0, 
					0,
					ISNULL(valorTotal123, 0) /  (SELECT VALOR FROM valor_total) * 100) AS PORC

			INTO #ABC FROM #TBS010 A (NOLOCK)
				LEFT JOIN vendas_devolucoes ON codigoProduto  = PROCOD

			-- Filtrar os produtos que tiveram vendas, devolucoes ou saldos diferentes de zero
			WHERE
				ISNULL(valorTotal123, 0) <> 0
				OR ISNULL(valorTotalDev123, 0) <> 0
				OR ISNULL(EST1, 0) <> 0 
				OR ISNULL(EST2, 0) <> 0 
				OR ISNULL(ESTQTDRES,0) <> 0
				OR ISNULL(ESTQTDPEN,0) <> 0 
				OR ISNULL(ESTQTDCMP,0) <> 0

			-- Calcula o acumulado de porcentagem									
			SELECT
				*,
				ROUND((SELECT SUM(TInt.PORC) FROM #ABC AS TInt WHERE TInt.ordem <= TOut.ordem ), 4) As PercAcum
			INTO #ABC_PORCENT FROM #ABC AS TOut		
		
			SELECT
				*,
				IIF(VENVALTOT <= 0, 'D', 
				IIF(PercAcum < 80 OR ordem = 1, 'A',
				IIF(PercAcum > 80 AND PercAcum < 95, 'B', 'C')))
				AS ABCD							
			INTO #ABCD FROM #ABC_PORCENT
										
			-- Devido ao erro que acontece no SQL SERVER, "falta de recursos", utilizaremos a partir desse ponto, tabelas temporarias #....

			-- Contabiliza quantidade e valore para cada curva(A,B,C,D)
			SELECT
				ABCD,
				COUNT(*) AS 'ABCD_QTD',
				SUM(VENVALTOT) AS 'ABCD_VAL'
			INTO #ABCD_COUNT_SUM FROM #ABCD

			GROUP BY
				ABCD
						
			-- Tabela final...
			SELECT 
				UNIDADE,
				PROSTATUS AS 'STA',
				PROCOD as 'CODIGO',
				PRODES as 'DESCRICAO',							
				MARCA,
				PROUM1 as 'UN1',

				-- SALDO
				ESTOQUE AS 'SALDO_ESTOQUE',
				LOJA AS 'SALDO_LOJA',
				ESTQTDDIS AS 'SOMA_EST_LOJ',
				ESTQTDRES AS RESER,
				ESTQTDPEN AS PENDENTE,
				ESTQTDCMP AS COMPRAS,

				-- SOMA AS QTDS VENDIDAS / PELA QUANTIDADE DE DIAS UTEIS, CASO >0 , SOMA SALDO TOTAL (NEGATIVO = 0 ) + COMPRAS - PENDENTE + QUANTIDADE EM TRANSITO / (VEN_UTEIS) 

				CONVERT(DECIMAL(10,4),
				CASE WHEN VENQTDTOT > 0  -- SABER QUANTIDADE DIARIA DAS VENDAS
					THEN ISNULL(round((ESTQTDDIS + ESTQTDCMP - ESTQTDPEN + QTDTRAN)/  (VENQTDTOT / @DiasUteis),0),0) -- QUANTOS DIAS AINDA TENHO EM ESTOQUE
					ELSE 0 
				END) AS 'TEMPO_RESTANTE', 

				-- USUARIO ESCOLHE A QUANTIDADE DE DIAS UTEIS PARA REPOSIcaO 
				-- @DiasReposicao - (SOMA AS QTDS VENDIDAS / PELA QUANTIDADE DE DIAS UTEIS, CASO >0 , 
				-- SOMA SALDO TOTAL + COMPRAS + SALDO CD - PENDENTE + QTD EM TRANSITO / (QTDS VENDAS / PELA QUANTIDADE DE DIAS UTEIS)) * VEN_UTEIS CASO <=0.9 � 0 (ZERO)
				-- ELSE @DiasReposicao - (SOMA AS QTDS VENDIDAS / PELA QUANTIDADE DE DIAS UTEIS, CASO >0 , 
				-- SOMA SALDO TOTAL + COMPRAS + SALDO CD - PENDENTE + QTD EM TRANSITO / (QTDS VENDAS / PELA QUANTIDADE DE DIAS UTEIS)) ( 
				-- PARA SABER QUANTOS DIAS , DEPOIS MULTIPLICAR PELA QUANTIDADE VENDIDA POR DIA) * VEN_UTEIS -- DAI SABEREI A QTD PARA REPOSIcaO

				-- PASSO 1: USUARIO ESCOLHE A QUANTIDADE DE DIAS UTEIS PARA REPOSIcaO 
				-- PASSO 2: VERIFICA SE QTD VENDIDA NO TOTAL MAIOR QUE ZERO, SE SIM PASSO 3, SE NAO , 0
				-- PASSO 3: DIAS REPOSIcaO (@DiasReposicao) - (SOMA ESTOQUE + COMPRAS - PENDENCIA) / (VENDAS TOTAIS / DIAS UTEIS) *

				case when @zeraQtdRepor = 'N'
					THEN
						CASE WHEN VENQTDTOT > 0 -- PRECISO SABER SE MAIOR QUE ZERO PQ VOU DIVIDIR POR ELE 
							THEN 
								CASE WHEN @DiasReposicao - (round((ESTQTDDIS + ESTQTDCMP - ESTQTDPEN + QTDTRAN) / (VENQTDTOT / @DiasUteis),0)) < 0 -- DIAS PARA REPOR - QUANTOS DIAS AINDA TENHO EM ESTOQUE
									THEN 0																						-- PRECISO SABER SE A QUANTIADE DE DIAS PARA REPOR MAIOR QUE ZERO
									ELSE (@DiasReposicao - (round((ESTQTDDIS + ESTQTDCMP - ESTQTDPEN + QTDTRAN) / (VENQTDTOT / @DiasUteis),0))) *	-- SE MENOR QUE ZERO A QTD PARA REPOR IRIA NEGATIVA
										(VENQTDTOT / @DiasUteis) -- QTD VENDIDA POR DIA
								END 
							ELSE 0 -- QTD VENDIDA POR DIA
						END
					ELSE 0
				END AS 'QTDPARAREPOR',

				-- QUANTIDADE EM TRANSITO
				QTDTRAN AS 'QTD_TRANSITO',

				-- 1o PERIODO QTD
				@DIA1 AS DIASU1,
				LOJAQTD1 AS 'GZ1',
				CORPQTD1 AS 'INT1',
				DEVQTD1 AS 'DEV1',
				VENQTDTOT1,
				VENQTDTOT1 / @DIA1 AS 'MEDIA_POR_DIA1',

				-- 2o PERIODO QTD
				@DIA2 AS DIASU2,
				LOJAQTD2 AS 'GZ2',
				CORPQTD2 AS 'INT2',
				DEVQTD2 AS 'DEV2',
				VENQTDTOT2,
				VENQTDTOT2 / @DIA2 AS 'MEDIA_POR_DIA2',

				-- 3o PERIODO QTD 
				@DIA3 AS DIASU3,
				LOJAQTD3 AS 'GZ3',
				CORPQTD3 AS 'INT3',
				DEVQTD3 AS 'DEV3',
				VENQTDTOT3,
				VENQTDTOT3 / @DIA3 AS 'MEDIA_POR_DIA3',

				A.ABCD,

				ISNULL((SELECT TOP 1 ABCD_QTD FROM #ABCD_COUNT_SUM WHERE ABCD = 'A'), 0) AS 'A',
				ISNULL((SELECT TOP 1 ABCD_QTD FROM #ABCD_COUNT_SUM WHERE ABCD = 'B'), 0) AS 'B',
				ISNULL((SELECT TOP 1 ABCD_QTD FROM #ABCD_COUNT_SUM WHERE ABCD = 'C'), 0) AS 'C',
				ISNULL((SELECT TOP 1 ABCD_QTD FROM #ABCD_COUNT_SUM WHERE ABCD = 'D'), 0) AS 'D',

				ISNULL((SELECT TOP 1 ABCD_VAL FROM #ABCD_COUNT_SUM WHERE ABCD = 'A'), 0) AS 'VAL_A',
				ISNULL((SELECT TOP 1 ABCD_VAL FROM #ABCD_COUNT_SUM WHERE ABCD = 'B'), 0) AS 'VAL_B',
				ISNULL((SELECT TOP 1 ABCD_VAL FROM #ABCD_COUNT_SUM WHERE ABCD = 'C'), 0) AS 'VAL_C',

				PORC AS 'Porc_VENDAS',
				VENVALTOT,
				VENQTDTOT,
				DEVQTDTOT,
				DEVVALTOT,
				VALOR,

				VENQTDTOT / @DiasUteis as VEN_UTEIS,

				(VENQTDTOT / @DiasUteis ) * 6 AS SEMENAL,

				((VENQTDTOT / @DiasUteis ) * 6 ) * 4 AS MENSAL,
				PRECO = ISNULL((SELECT TDPCUSREA FROM TBS031 D (NOLOCK) WHERE A.PROCOD = D.TDPPROCOD),0) 

			INTO #ABCD_FINAL FROM #ABCD A
				--JOIN #ABCD_COUNT_SUM B ON A.ABCD = B.ABCD
					
			SELECT 
				*,
				PRECO * QTDPARAREPOR AS SUGCMP
			FROM #ABCD_FINAL

			ORDER BY
				VENVALTOT DESC		


			IF @GravarCurvaProduto = 'S'			
			BEGIN
				PRINT 'Atualizando a letra da curva no cadastro de produtos...'

				-- Zera antes de atualizar o cadastro
				UPDATE TBS010
					SET PROCURABC = ''
				FROM TBS010			
				WHERE PROCURABC <> ''

				UPDATE TBS010
					SET PROCURABC = ABCD
				FROM TBS010
				INNER JOIN #ABCD_FINAL ON CODIGO = PROCOD
			END

	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
		-- Apaga as temporarias globais

		DROP TABLE ##DWVendas;
		DROP TABLE ##DWDevolucaoVendas;	

	------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	END	
	ELSE 
	
	BEGIN 
		SELECT TOP 1
			'' AS UNIDADE ,
			'' AS 'STA',
			'' as 'CODIGO',
			'O periodo 1 ate ou o periodo 2 ate esta maior ou igual que o Periodo 3 ate; ou o periodo 1 ate esta maior ou igual que o periodo 2 ate; isso gera erro, favor corrigir.' as 'DESCRICAO',
			'' AS MARCA,
			'' as 'UN1',

			-- SALDO
			0 AS 'SALDO_ESTOQUE',
			0 AS 'SALDO_LOJA',
			0 AS 'SOMA_EST_LOJ',
			0 AS RESER,
			0 AS PENDENTE,
			0 AS COMPRAS,

			-- SOMA AS QTDS VENDIDAS / PELA QUANTIDADE DE DIAS UTEIS, CASO >0 , SOMA SALDO TOTAL (NEGATIVO = 0 ) + COMPRAS - PENDENTE / (VEN_UTEIS) 

			0 AS 'TEMPO_RESTANTE', 

			-- USUARIO ESCOLHE A QUANTIDADE DE DIAS UTEIS PARA REPOSIcaO 
			-- @DiasReposicao - (SOMA AS QTDS VENDIDAS / PELA QUANTIDADE DE DIAS UTEIS, CASO >0 , 
			-- SOMA SALDO TOTAL + COMPRAS + SALDO CD - PENDENTE / (QTDS VENDAS / PELA QUANTIDADE DE DIAS UTEIS)) * VEN_UTEIS CASO <=0.9 � 0 (ZERO)
			-- ELSE @DiasReposicao - (SOMA AS QTDS VENDIDAS / PELA QUANTIDADE DE DIAS UTEIS, CASO >0 , 
			-- SOMA SALDO TOTAL + COMPRAS + SALDO CD - PENDENTE / (QTDS VENDAS / PELA QUANTIDADE DE DIAS UTEIS)) ( 
			-- PARA SABER QUANTOS DIAS , DEPOIS MULTIPLICAR PELA QUANTIDADE VENDIDA POR DIA) * VEN_UTEIS -- DAI SABEREI A QTD PARA REPOSIcaO

			-- PASSO 1: USUARIO ESCOLHE A QUANTIDADE DE DIAS UTEIS PARA REPOSIcaO 
			-- PASSO 2: VERIFICA SE QTD VENDIDA NO TOTAL � MAIOR QUE ZERO, SE SIM PASSO 3
			-- PASSO 3: DIAS REPOSIcaO (@DiasReposicao) - (SOMA ESTOQUE + COMPRAS - PENDENCIA) / (VENDAS TOTAIS / DIAS UTEIS)

			0 AS 'QTDPARAREPOR',

			-- QUANTIDADE EM TRANSITO
			0 AS 'QTD_TRANSITO',

			-- 1o PERIODO QTD
			0 AS DIASU1,
			0 AS 'GZ1',
			0 AS 'INT1',
			0 AS 'DEV1',
			0 AS 'MEDIA_POR_DIA1' ,
			0 AS VENQTDTOT1,

			-- 2o PERIODO QTD
			0 AS DIASU2,
			0 AS 'GZ2',
			0 AS 'INT2',
			0 AS 'DEV2',
			0 AS 'MEDIA_POR_DIA2' ,
			0 AS VENQTDTOT2,

			-- 3o PERIODO QTD 
			0 AS DIASU3,
			0 AS 'GZ3',
			0 AS 'INT3',
			0 AS 'DEV3',
			0 AS 'MEDIA_POR_DIA3',
			0 AS VENQTDTOT3,
			'' as ABCD,
			0 AS 'A',
			0 AS 'B',
			0 AS 'C',
			0 AS 'D',
			0 AS 'VAL_A',
			0 AS 'VAL_B',
			0 AS 'VAL_C',
			0 AS 'Porc_VENDAS',
			0 as VENVALTOT,
			0 as VENQTDTOT,
			0 as DEVQTDTOT,
			0 as DEVVALTOT,
			0 as VALOR,
			0 as VEN_UTEIS,
			0 AS SEMENAL,
			0 AS MENSAL,
			0 as PRECO ,
			0 as SUGCMP
		FROM TBS010 (NOLOCK)
/**/		
	END

END