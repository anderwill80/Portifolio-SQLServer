/*
====================================================================================================================================================================================
Permite obter o fatualmente anual, mês a mês com porcetagem de evolução entre os meses e os anos
SP sera utilizada dentro de outra SP de relatorio do RS, onde poderemos filtrar qual empresa do grupo mostrara os faturamentos
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================10/04/2025 WILLIAM
17/03/2026 WILLIAM
	- Aumento da precisacao dos atributos referentes a evolucao, de decimal(7,2) para decimal(8,2);
16/03/2026 WILLIAM
	- Inclusao de colunas com porcentagem que cada grupo de faturamento representa no total, corporativo, loja e grupo para cada mes;
13/03/2026 WILLIAM
	- Inclusao do nome da empresa que esta executando o relatorio na tabela final;
11/03/2026 WILLIAM
	- Criacao;
====================================================================================================================================================================================
*/
--CREATE PROC [dbo].[usp_Get_DWVendas_FaturamentoAnual]
ALTER PROC [dbo].[usp_Get_DWVendas_FaturamentoAnual] 
	@pEmpCod SMALLINT,
	@pDataDe DATE = NULL, 
	@pDataAte DATE = NULL,
	@pContabiliza VARCHAR(10) = 'C,L'	-- Padrao: contabilizar vendas do 'C'orporativo e 'L'oja;
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @dataDe date, @dataAte date, @VENCOD varchar(500), @GruposVendedores varchar(100), @contabiliza varchar(10),
	@EmpresaLocalCNPJ VARCHAR(20), @EmpresaLocalNome VARCHAR(20);;
			 
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod	
	SET @dataDe = (SELECT ISNULL(@pDataDe, '17530101'));
	SET @dataAte = (SELECT ISNULL(@pDataAte, GETDATE() - 1));
	SET @contabiliza = UPPER(@pContabiliza);

-- Atribuicoes locais

	SET @EmpresaLocalCNPJ = (SELECT TOP 1 RTRIM(LTRIM(EMPCGC)) AS  EMPCGC FROM TBS023 (NOLOCK) WHERE EMPCOD = @codigoEmpresa)

	-- Define o nome da empresa que esta executando o relatorio, para a tabela final
	SET @EmpresaLocalNome =
	CASE
		WHEN @EmpresaLocalCNPJ = '05118717000156' then 'BESTBAG'
		WHEN @EmpresaLocalCNPJ = '52080207000117' then 'MISASPEL'
		WHEN @EmpresaLocalCNPJ = '44125185000136' then 'PAPELYNA'
		WHEN @EmpresaLocalCNPJ = '41952080000162' then 'WINPACK'
		WHEN @EmpresaLocalCNPJ = '65069593000198' then 'TANBY MATRIZ'
		WHEN @EmpresaLocalCNPJ = '65069593000350' then 'TANBY CD'
		WHEN @EmpresaLocalCNPJ = '65069593000279' then 'TANBY TAUBATE'				
	END
	
/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @dataDe,
		@pdataAte = @dataAte,
		@pcontabiliza = @contabiliza

/***********************************************************************************************************************************************************************************
	Obter as devolucoes da tabela DWDevolucaoVendas
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @dataDe,
		@pdataAte = @dataAte,
		@pcontabiliza = @contabiliza		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

    BEGIN TRY
        
	-- Utilizaremos CTE para facilitar a codificacao...
	;WITH
		-- Faturamento: CORPORATIVO
		
		-- Vendas agrupadas por ano, mes
		vendas_ano_mes_corp AS(		
		SELECT 
			YEAR(data) AS ano,
			MONTH(data) AS mes,
			SUM(valorTotal) AS vendas
		FROM ##DWVendas		
	 	WHERE 
			contabiliza = 'C'
			AND documentoReferenciado = ''
		GROUP BY 
			YEAR(data), 
			MONTH(data)			
		),
		--SELECT * from vendas_ano_mes order by ano, mes;
		
		-- Devolucoes agrupadas por ano, mes e vendedor
		devolucoes_ano_mes_corp AS(		
		SELECT					
			YEAR(data) AS ano,
			MONTH(data) AS mes,
			SUM(valorTotal) AS devolucao
		FROM ##DWDevolucaoVendas
		WHERE 
			contabiliza = 'C'			

		GROUP BY 			
			YEAR(data), 
			MONTH(data)	
		),
--		SELECT * from  devolucoes_ano_mes;
		-- Abate devolucao caso exista
		faturamento_corp AS(
		SELECT 
			v.ano,
			v.mes,
			CAST(vendas - ISNULL(devolucao, 0) AS DECIMAL(19,4)) AS fatCorp
		FROM vendas_ano_mes_corp v
		LEFT JOIN devolucoes_ano_mes_corp d ON 
			d.ano = v.ano AND
			d.mes = v.mes
		),

		-- Faturamento: LOJA		
		vendas_ano_mes_loja AS(		
		SELECT 
			YEAR(data) AS ano,
			MONTH(data) AS mes,
			SUM(valorTotal) AS vendas
		FROM ##DWVendas		
	 	WHERE 
			contabiliza = 'L'
			AND documentoReferenciado = ''
			
		GROUP BY 
			YEAR(data), 
			MONTH(data)			
		),
		--SELECT * from vendas_ano_mes order by ano, mes;
		
		-- Devolucoes agrupadas por ano, mes e vendedor
		devolucoes_ano_mes_loja AS(		
		SELECT					
			YEAR(data) AS ano,
			MONTH(data) AS mes,
			SUM(valorTotal) AS devolucao
		FROM ##DWDevolucaoVendas
		WHERE 
			contabiliza = 'L'

		GROUP BY 			
			YEAR(data), 
			MONTH(data)	
		),
--		SELECT * from  devolucoes_ano_mes;
		-- Abate devolucao caso exista
		faturamento_loja AS(
		SELECT 
			v.ano,
			v.mes,
			CAST(vendas - ISNULL(devolucao, 0) AS DECIMAL(19,4)) AS fatLoja
		FROM vendas_ano_mes_loja v
		LEFT JOIN devolucoes_ano_mes_loja d ON 
			d.ano = v.ano AND
			d.mes = v.mes
		),

		-- Faturamento: GRUPO BMPT		
		vendas_ano_mes_grup AS(		
		SELECT 
			YEAR(data) AS ano,
			MONTH(data) AS mes,
			SUM(valorTotal) AS vendas
		FROM ##DWVendas		
	 	WHERE 						
			contabiliza = 'G'
			AND documentoReferenciado = ''
		GROUP BY 
			YEAR(data), 
			MONTH(data)			
		),
		--SELECT * from vendas_ano_mes order by ano, mes;
		
		-- Devolucoes agrupadas por ano, mes e vendedor
		devolucoes_ano_mes_grup AS(		
		SELECT					
			YEAR(data) AS ano,
			MONTH(data) AS mes,
			SUM(valorTotal) AS devolucao
		FROM ##DWDevolucaoVendas
		WHERE 
			contabiliza = 'G'

		GROUP BY 			
			YEAR(data), 
			MONTH(data)	
		),
		-- Abate devolucao caso exista
		faturamento_grup AS(
		SELECT 
			v.ano,
			v.mes,
			CAST(vendas - ISNULL(devolucao, 0) AS DECIMAL(19,4)) AS fatGrup
		FROM vendas_ano_mes_grup v
		LEFT JOIN devolucoes_ano_mes_grup d ON 
			d.ano = v.ano AND
			d.mes = v.mes
		),

-- Gerar tabelas de faturamento pivoteada, com os meses como colunas: janeiro | fevereiro | março | .... | dezembro

		-- Pivoteamento do faturamento da CORPORATIVO
		faturamento_corp_pivot AS(
		SELECT 			
			ano,
			CAST(ISNULL([1], 0)  AS DECIMAL(19, 4)) AS fatJanCorp,
			CAST(ISNULL([2], 0)  AS DECIMAL(19, 4)) AS fatFevCorp,
			CAST(ISNULL([3], 0)  AS DECIMAL(19, 4)) AS fatMarCorp,
			CAST(ISNULL([4], 0)  AS DECIMAL(19, 4)) AS fatAbrCorp,
			CAST(ISNULL([5], 0)  AS DECIMAL(19, 4)) AS fatMaiCorp,
			CAST(ISNULL([6], 0)  AS DECIMAL(19, 4)) AS fatJunCorp,
			CAST(ISNULL([7], 0)  AS DECIMAL(19, 4)) AS fatJulCorp,
			CAST(ISNULL([8], 0)  AS DECIMAL(19, 4)) AS fatAgoCorp,
			CAST(ISNULL([9], 0)  AS DECIMAL(19, 4)) AS fatSetCorp,
			CAST(ISNULL([10], 0) AS DECIMAL(19, 4)) AS fatOutCorp,
			CAST(ISNULL([11], 0) AS DECIMAL(19, 4)) AS fatNovCorp,
			CAST(ISNULL([12], 0) AS DECIMAL(19, 4)) AS fatDezCorp
		FROM faturamento_corp PIVOT (SUM(fatCorp) FOR mes IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])) P		
		),

		-- Pivoteamento do faturamento da LOJA
		faturamento_loja_pivot AS(
		SELECT 			
			ano,
			CAST(ISNULL([1], 0)  AS DECIMAL(19, 4)) AS fatJanLoja,
			CAST(ISNULL([2], 0)  AS DECIMAL(19, 4)) AS fatFevLoja,
			CAST(ISNULL([3], 0)  AS DECIMAL(19, 4)) AS fatMarLoja,
			CAST(ISNULL([4], 0)  AS DECIMAL(19, 4)) AS fatAbrLoja,
			CAST(ISNULL([5], 0)  AS DECIMAL(19, 4)) AS fatMaiLoja,
			CAST(ISNULL([6], 0)  AS DECIMAL(19, 4)) AS fatJunLoja,
			CAST(ISNULL([7], 0)  AS DECIMAL(19, 4)) AS fatJulLoja,
			CAST(ISNULL([8], 0)  AS DECIMAL(19, 4)) AS fatAgoLoja,
			CAST(ISNULL([9], 0)  AS DECIMAL(19, 4)) AS fatSetLoja,
			CAST(ISNULL([10], 0) AS DECIMAL(19, 4)) AS fatOutLoja,
			CAST(ISNULL([11], 0) AS DECIMAL(19, 4)) AS fatNovLoja,
			CAST(ISNULL([12], 0) AS DECIMAL(19, 4)) AS fatDezLoja
		FROM faturamento_loja PIVOT (SUM(fatLoja) FOR mes IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])) P		
		),

		-- Pivoteamento do faturamento da GRUPO BMPT
		faturamento_grup_pivot AS(
		SELECT 			
			ano,
			CAST(ISNULL([1], 0)  AS DECIMAL(19, 4)) AS fatJanGrup,
			CAST(ISNULL([2], 0)  AS DECIMAL(19, 4)) AS fatFevGrup,
			CAST(ISNULL([3], 0)  AS DECIMAL(19, 4)) AS fatMarGrup,
			CAST(ISNULL([4], 0)  AS DECIMAL(19, 4)) AS fatAbrGrup,
			CAST(ISNULL([5], 0)  AS DECIMAL(19, 4)) AS fatMaiGrup,
			CAST(ISNULL([6], 0)  AS DECIMAL(19, 4)) AS fatJunGrup,
			CAST(ISNULL([7], 0)  AS DECIMAL(19, 4)) AS fatJulGrup,
			CAST(ISNULL([8], 0)  AS DECIMAL(19, 4)) AS fatAgoGrup,
			CAST(ISNULL([9], 0)  AS DECIMAL(19, 4)) AS fatSetGrup,
			CAST(ISNULL([10], 0) AS DECIMAL(19, 4)) AS fatOutGrup,
			CAST(ISNULL([11], 0) AS DECIMAL(19, 4)) AS fatNovGrup,
			CAST(ISNULL([12], 0) AS DECIMAL(19, 4)) AS fatDezGrup
		FROM faturamento_grup PIVOT (SUM(fatGrup) FOR mes IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])) P		
		),

		-- Cria uma tabela com as datas dos faturamentos, para ser como base
		faturamentos_ano AS(
		SELECT DISTINCT ano FROM faturamento_corp
		UNION
		SELECT DISTINCT ano FROM faturamento_loja
		UNION
		SELECT DISTINCT ano FROM faturamento_grup
		),
		
		-- Unifica os faturamentos do corporativo, loja e grupo, baseado na tabela de anos únicos
		faturamentos_unificados AS(
		SELECT
			d.ano,
			ISNULL(fatJanCorp, 0) AS fatJanCorp,
			ISNULL(fatJanLoja, 0) AS fatJanLoja,
			ISNULL(fatJanGrup, 0) AS fatJanGrup,
			CAST(ISNULL(fatJanCorp, 0) + ISNULL(fatJanLoja, 0) + ISNULL(fatJanGrup, 0) AS DECIMAL(19, 4)) AS fatJan,

			ISNULL(fatFevCorp, 0) AS fatFevCorp,
			ISNULL(fatFevLoja, 0) AS fatFevLoja,
			ISNULL(fatFevGrup, 0) AS fatFevGrup,
			CAST(ISNULL(fatFevCorp, 0) + ISNULL(fatFevLoja, 0) + ISNULL(fatFevGrup, 0) AS DECIMAL(19, 4))  AS fatFev,

			ISNULL(fatMarCorp, 0) AS fatMarCorp,
			ISNULL(fatMarLoja, 0) AS fatMarLoja,
			ISNULL(fatMarGrup, 0) AS fatMarGrup,
			CAST(ISNULL(fatMarCorp, 0) + ISNULL(fatMarLoja, 0) + ISNULL(fatMarGrup, 0) AS DECIMAL(19, 4)) AS fatMar,

			ISNULL(fatAbrCorp, 0) AS fatAbrCorp,
			ISNULL(fatAbrLoja, 0) AS fatAbrLoja,
			ISNULL(fatAbrGrup, 0) AS fatAbrGrup,
			CAST(ISNULL(fatAbrCorp, 0) + ISNULL(fatAbrLoja, 0) + ISNULL(fatAbrGrup, 0) AS DECIMAL(19, 4)) AS fatAbr,

			ISNULL(fatMaiCorp, 0) AS fatMaiCorp,
			ISNULL(fatMaiLoja, 0) AS fatMaiLoja,
			ISNULL(fatMaiGrup, 0) AS fatMaiGrup,
			CAST(ISNULL(fatMaiCorp, 0) + ISNULL(fatMaiLoja, 0) + ISNULL(fatMaiGrup, 0) AS DECIMAL(19, 4)) AS fatMai,

			ISNULL(fatJunCorp, 0) AS fatJunCorp,
			ISNULL(fatJunLoja, 0) AS fatJunLoja,
			ISNULL(fatJunGrup, 0) AS fatJunGrup,
			CAST(ISNULL(fatJunCorp, 0) + ISNULL(fatJunLoja, 0) + ISNULL(fatJunGrup, 0) AS DECIMAL(19, 4)) AS fatJun,

			ISNULL(fatJulCorp, 0) AS fatJulCorp,
			ISNULL(fatJulLoja, 0) AS fatJulLoja,
			ISNULL(fatJulGrup, 0) AS fatJulGrup,
			CAST(ISNULL(fatJulCorp, 0) + ISNULL(fatJulLoja, 0) + ISNULL(fatJulGrup, 0) AS DECIMAL(19, 4)) AS fatJul,

			ISNULL(fatAgoCorp, 0) AS fatAgoCorp,
			ISNULL(fatAgoLoja, 0) AS fatAgoLoja,
			ISNULL(fatAgoGrup, 0) AS fatAgoGrup,
			CAST(ISNULL(fatAgoCorp, 0) + ISNULL(fatAgoLoja, 0) + ISNULL(fatAgoGrup, 0) AS DECIMAL(19, 4)) AS fatAgo,

			ISNULL(fatSetCorp, 0) AS fatSetCorp,
			ISNULL(fatSetLoja, 0) AS fatSetLoja,
			ISNULL(fatSetGrup, 0) AS fatSetGrup,
			CAST(ISNULL(fatSetCorp, 0) + ISNULL(fatSetLoja, 0) + ISNULL(fatSetGrup, 0) AS DECIMAL(19, 4)) AS fatSet,

			ISNULL(fatOutCorp, 0) AS fatOutCorp,
			ISNULL(fatOutLoja, 0) AS fatOutLoja,
			ISNULL(fatOutGrup, 0) AS fatOutGrup,
			CAST(ISNULL(fatOutCorp, 0) + ISNULL(fatOutLoja, 0) + ISNULL(fatOutGrup, 0) AS DECIMAL(19, 4)) AS fatOut,

			ISNULL(fatNovCorp, 0) AS fatNovCorp,
			ISNULL(fatNovLoja, 0) AS fatNovLoja,
			ISNULL(fatNovGrup, 0) AS fatNovGrup,
			CAST(ISNULL(fatNovCorp, 0) + ISNULL(fatNovLoja, 0) + ISNULL(fatNovGrup, 0) AS DECIMAL(19, 4)) AS fatNov,

			ISNULL(fatDezCorp, 0) AS fatDezCorp,
			ISNULL(fatDezLoja, 0) AS fatDezLoja,						
			ISNULL(fatDezGrup, 0) AS fatDezGrup,
			CAST(ISNULL(fatDezCorp, 0) + ISNULL(fatDezLoja, 0) + ISNULL(fatDezGrup, 0) AS DECIMAL(19, 4)) AS fatDez,

			CAST(
			ISNULL(fatJanCorp, 0) + ISNULL(fatJanLoja, 0) + ISNULL(fatJanGrup, 0) +
			ISNULL(fatFevCorp, 0) + ISNULL(fatFevLoja, 0) + ISNULL(fatFevGrup, 0) +
			ISNULL(fatMarCorp, 0) + ISNULL(fatMarLoja, 0) + ISNULL(fatMarGrup, 0) +
			ISNULL(fatAbrCorp, 0) + ISNULL(fatAbrLoja, 0) + ISNULL(fatAbrGrup, 0) +
			ISNULL(fatMaiCorp, 0) + ISNULL(fatMaiLoja, 0) + ISNULL(fatMaiGrup, 0) + 
			ISNULL(fatJunCorp, 0) + ISNULL(fatJunLoja, 0) + ISNULL(fatJunGrup, 0) +
			ISNULL(fatJulCorp, 0) + ISNULL(fatJulLoja, 0) + ISNULL(fatJulGrup, 0) + 
			ISNULL(fatAgoCorp, 0) + ISNULL(fatAgoLoja, 0) + ISNULL(fatAgoGrup, 0) +
			ISNULL(fatSetCorp, 0) + ISNULL(fatSetLoja, 0) + ISNULL(fatSetGrup, 0) +
			ISNULL(fatOutCorp, 0) + ISNULL(fatOutLoja, 0) + ISNULL(fatOutGrup, 0) +
			ISNULL(fatNovCorp, 0) + ISNULL(fatNovLoja, 0) + ISNULL(fatNovGrup, 0) +
			ISNULL(fatDezCorp, 0) + ISNULL(fatDezLoja, 0) + ISNULL(fatDezGrup, 0) AS DECIMAL(19,4))
			AS fatAno
			
		FROM faturamentos_ano d
		LEFT JOIN faturamento_corp_pivot fc ON fc.ano = d.ano
		LEFT JOIN faturamento_loja_pivot fl ON fl.ano = d.ano
		LEFT JOIN faturamento_grup_pivot fg ON fg.ano = d.ano
		),	
	
		-- Obtem o faturamento do ano anterior via "WINDOWS FUNCTION" LAG() OVER()
		faturamento_mensal_ano_anterior AS(
		SELECT 	
			*,
			CAST(SIGN(fatJan) + SIGN(fatFev) + SIGN(fatMar) + SIGN(fatAbr) + SIGN(fatMai) + SIGN(fatJun) + SIGN(fatJul) + SIGN(fatAgo) + SIGN(fatSet) + SIGN(fatOut) + SIGN(fatNov) + SIGN(fatDez) AS INT) 
			AS qtdMeses,

			CAST((LAG(fatJan, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatJanA,
			CAST((LAG(fatFev, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatFevA,
			CAST((LAG(fatMar, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatMarA,

			CAST((LAG(fatAbr, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatAbrA,
			CAST((LAG(fatMai, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatMaiA,
			CAST((LAG(fatJun, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatJunA,

			CAST((LAG(fatJul, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatJulA,
			CAST((LAG(fatAgo, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatAgoA,
			CAST((LAG(fatSet, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatSetA,

			CAST((LAG(fatOut, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatOutA,
			CAST((LAG(fatNov, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatNovA,
			CAST((LAG(fatDez, 1, 0) OVER (ORDER BY ano)) AS DECIMAL(19, 4)) AS fatDezA,

			CAST((LAG(fatAno, 1, 0) OVER ( ORDER BY ano)) AS DECIMAL(19, 4)) AS fatAnoA
		FROM faturamentos_unificados
		),

		-- Com os faturamentos atuais e anteriores do ano e mes, 
		-- calcula a evolucao mensal referente ao mes passado e o mesmo mes ano anterior em %
		faturamento_mensal_ano_evolucao AS(
		SELECT			
			*,
			CAST(ISNULL(NULLIF(fatJanCorp, 0) / NULLIF(fatJan, 0) * 100., 0) AS DECIMAL(7, 2)) AS perJanCorp,
			CAST(ISNULL(NULLIF(fatJanLoja, 0) / NULLIF(fatJan, 0) * 100., 0) AS DECIMAL(7, 2)) AS perJanLoja,
			CAST(ISNULL(NULLIF(fatJanGrup, 0) / NULLIF(fatJan, 0) * 100., 0) AS DECIMAL(7, 2)) AS perJanGrup,

			CAST(ISNULL(NULLIF(fatFevCorp, 0) / NULLIF(fatFev, 0) * 100., 0) AS DECIMAL(7, 2)) AS perFevCorp,
			CAST(ISNULL(NULLIF(fatFevLoja, 0) / NULLIF(fatFev, 0) * 100., 0) AS DECIMAL(7, 2)) AS perFevLoja,
			CAST(ISNULL(NULLIF(fatFevGrup, 0) / NULLIF(fatFev, 0) * 100., 0) AS DECIMAL(7, 2)) AS perFevGrup,

			CAST(ISNULL(NULLIF(fatMarCorp, 0) / NULLIF(fatMar, 0) * 100., 0) AS DECIMAL(7, 2)) AS perMarCorp,
			CAST(ISNULL(NULLIF(fatMarLoja, 0) / NULLIF(fatMar, 0) * 100., 0) AS DECIMAL(7, 2)) AS perMarLoja,
			CAST(ISNULL(NULLIF(fatMarGrup, 0) / NULLIF(fatMar, 0) * 100., 0) AS DECIMAL(7, 2)) AS perMarGrup,

			CAST(ISNULL(NULLIF(fatAbrCorp, 0) / NULLIF(fatAbr, 0) * 100., 0) AS DECIMAL(7, 2)) AS perAbrCorp,
			CAST(ISNULL(NULLIF(fatAbrLoja, 0) / NULLIF(fatAbr, 0) * 100., 0) AS DECIMAL(7, 2)) AS perAbrLoja,
			CAST(ISNULL(NULLIF(fatAbrGrup, 0) / NULLIF(fatAbr, 0) * 100., 0) AS DECIMAL(7, 2)) AS perAbrGrup,

			CAST(ISNULL(NULLIF(fatMaiCorp, 0) / NULLIF(fatMai, 0) * 100., 0) AS DECIMAL(7, 2)) AS perMaiCorp,
			CAST(ISNULL(NULLIF(fatMaiLoja, 0) / NULLIF(fatMai, 0) * 100., 0) AS DECIMAL(7, 2)) AS perMaiLoja,
			CAST(ISNULL(NULLIF(fatMaiGrup, 0) / NULLIF(fatMai, 0) * 100., 0) AS DECIMAL(7, 2)) AS perMaiGrup,

			CAST(ISNULL(NULLIF(fatJunCorp, 0) / NULLIF(fatJun, 0) * 100., 0) AS DECIMAL(7, 2)) AS perJunCorp,
			CAST(ISNULL(NULLIF(fatJunLoja, 0) / NULLIF(fatJun, 0) * 100., 0) AS DECIMAL(7, 2)) AS perJunLoja,
			CAST(ISNULL(NULLIF(fatJunGrup, 0) / NULLIF(fatJun, 0) * 100., 0) AS DECIMAL(7, 2)) AS perJunGrup,

			CAST(ISNULL(NULLIF(fatJulCorp, 0) / NULLIF(fatJul, 0) * 100., 0) AS DECIMAL(7, 2)) AS perJulCorp,
			CAST(ISNULL(NULLIF(fatJulLoja, 0) / NULLIF(fatJul, 0) * 100., 0) AS DECIMAL(7, 2)) AS perJulLoja,
			CAST(ISNULL(NULLIF(fatJulGrup, 0) / NULLIF(fatJul, 0) * 100., 0) AS DECIMAL(7, 2)) AS perJulGrup,

			CAST(ISNULL(NULLIF(fatAgoCorp, 0) / NULLIF(fatAgo, 0) * 100., 0) AS DECIMAL(7, 2)) AS perAgoCorp,
			CAST(ISNULL(NULLIF(fatAgoLoja, 0) / NULLIF(fatAgo, 0) * 100., 0) AS DECIMAL(7, 2)) AS perAgoLoja,
			CAST(ISNULL(NULLIF(fatAgoGrup, 0) / NULLIF(fatAgo, 0) * 100., 0) AS DECIMAL(7, 2)) AS perAgoGrup,

			CAST(ISNULL(NULLIF(fatSetCorp, 0) / NULLIF(fatSet, 0) * 100., 0) AS DECIMAL(7, 2)) AS perSetCorp,
			CAST(ISNULL(NULLIF(fatSetLoja, 0) / NULLIF(fatSet, 0) * 100., 0) AS DECIMAL(7, 2)) AS perSetLoja,
			CAST(ISNULL(NULLIF(fatSetGrup, 0) / NULLIF(fatSet, 0) * 100., 0) AS DECIMAL(7, 2)) AS perSetGrup,

			CAST(ISNULL(NULLIF(fatOutCorp, 0) / NULLIF(fatOut, 0) * 100., 0) AS DECIMAL(7, 2)) AS perOutCorp,
			CAST(ISNULL(NULLIF(fatOutLoja, 0) / NULLIF(fatOut, 0) * 100., 0) AS DECIMAL(7, 2)) AS perOutLoja,
			CAST(ISNULL(NULLIF(fatOutGrup, 0) / NULLIF(fatOut, 0) * 100., 0) AS DECIMAL(7, 2)) AS perOutGrup,

			CAST(ISNULL(NULLIF(fatNovCorp, 0) / NULLIF(fatNov, 0) * 100., 0) AS DECIMAL(7, 2)) AS perNovCorp,
			CAST(ISNULL(NULLIF(fatNovLoja, 0) / NULLIF(fatNov, 0) * 100., 0) AS DECIMAL(7, 2)) AS perNovLoja,
			CAST(ISNULL(NULLIF(fatNovGrup, 0) / NULLIF(fatNov, 0) * 100., 0) AS DECIMAL(7, 2)) AS perNovGrup,

			CAST(ISNULL(NULLIF(fatDezCorp, 0) / NULLIF(fatDez, 0) * 100., 0) AS DECIMAL(7, 2)) AS perDezCorp,
			CAST(ISNULL(NULLIF(fatDezLoja, 0) / NULLIF(fatDez, 0) * 100., 0) AS DECIMAL(7, 2)) AS perDezLoja,
			CAST(ISNULL(NULLIF(fatDezGrup, 0) / NULLIF(fatDez, 0) * 100., 0) AS DECIMAL(7, 2)) AS perDezGrup,

			CAST(ISNULL((NULLIF(fatJan, 0) - fatDezA) / NULLIF(fatDezA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoJan,
			CAST(ISNULL((NULLIF(fatJan, 0) - fatJanA) / NULLIF(fatJanA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoJanA,

			CAST(ISNULL((NULLIF(fatFev, 0) - fatJan)  / NULLIF(fatJan, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoFev,
			CAST(ISNULL((NULLIF(fatFev, 0) - fatFevA) / NULLIF(fatFevA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoFevA,

			CAST(ISNULL((NULLIF(fatMar, 0) - fatFev)  / NULLIF(fatFev, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoMar,
			CAST(ISNULL((NULLIF(fatMar, 0) - fatMarA) / NULLIF(fatMarA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoMarA,

			CAST(ISNULL((NULLIF(fatAbr, 0) - fatMar)  / NULLIF(fatMar, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoAbr,
			CAST(ISNULL((NULLIF(fatAbr, 0) - fatAbrA) / NULLIF(fatAbrA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoAbrA,

			CAST(ISNULL((NULLIF(fatMai, 0) - fatAbr)  / NULLIF(fatAbr, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoMai,
			CAST(ISNULL((NULLIF(fatMai, 0) - fatMaiA) / NULLIF(fatMaiA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoMaiA,

			CAST(ISNULL((NULLIF(fatJun, 0) - fatMai)  / NULLIF(fatMai, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoJun,
			CAST(ISNULL((NULLIF(fatJun, 0) - fatJunA) / NULLIF(fatJunA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoJunA,
			
			CAST(ISNULL((NULLIF(fatJul, 0) - fatJun)  / NULLIF(fatJun, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoJul,
			CAST(ISNULL((NULLIF(fatJul, 0) - fatJulA) / NULLIF(fatJulA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoJulA,

			CAST(ISNULL((NULLIF(fatAgo, 0) - fatJul)  / NULLIF(fatJul, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoAgo,
			CAST(ISNULL((NULLIF(fatAgo, 0) - fatAgoA) / NULLIF(fatAgoA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoAgoA,

			CAST(ISNULL((NULLIF(fatSet, 0) - fatAgo)  / NULLIF(fatAgo, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoSet,
			CAST(ISNULL((NULLIF(fatSet, 0) - fatSetA) / NULLIF(fatSetA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoSetA,

			CAST(ISNULL((NULLIF(fatOut, 0) - fatSet)  / NULLIF(fatSet, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoOut,
			CAST(ISNULL((NULLIF(fatOut, 0) - fatOutA) / NULLIF(fatOutA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoOutA,

			CAST(ISNULL((NULLIF(fatNov, 0) - fatOut)  / NULLIF(fatOut, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoNov,
			CAST(ISNULL((NULLIF(fatNov, 0) - fatNovA) / NULLIF(fatNovA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoNovA,

			CAST(ISNULL((NULLIF(fatDez, 0) - fatNov)  / NULLIF(fatNov, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoDez,
			CAST(ISNULL((NULLIF(fatDez, 0) - fatDezA) / NULLIF(fatDezA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoDezA,

			CAST(ISNULL((fatAno - fatAnoA) / NULLIF(fatAnoA, 0) * 100., 0) AS DECIMAL(8, 2)) AS evoAno,

			CAST(fatAno / NULLIF(qtdMeses, 0) AS DECIMAL(19, 4)) AS mediaMensal
		FROM faturamento_mensal_ano_anterior
		)	
		-- Tabela final
		SELECT 
			@EmpresaLocalNome AS empresa,
			ano,
			fatAno,
			evoAno,
			mediaMensal,
			fatJanCorp,
			perJanCorp,
			fatJanLoja,
			perJanLoja,
			fatJanGrup,
			perJanGrup,
			fatJan,
			evoJan,
			evoJanA,
			fatFevCorp,
			perFevCorp,
			fatFevLoja,
			perFevLoja,
			fatFevGrup,
			perFevGrup,
			fatFev,
			evoFev,
			evoFevA,
			fatMarCorp,
			perMarCorp,
			fatMarLoja, 
			perMarLoja,
			fatMarGrup,
			perMarGrup,
			fatMar,
			evoMar,
			evoMarA,
			fatAbrCorp,
			perAbrCorp,
			fatAbrLoja,
			perAbrLoja,
			fatAbrGrup,
			perAbrGrup,
			fatAbr,
			evoAbr,
			evoAbrA,
			fatMaiCorp,
			perMaiCorp,
			fatMaiLoja,
			perMaiLoja,
			fatMaiGrup,
			perMaiGrup,
			fatMai,
			evoMai,
			evoMaiA,
			fatJunCorp,
			perJunCorp,
			fatJunLoja,
			perJunLoja,
			fatJunGrup,
			perJunGrup,
			fatJun,
			evoJun,
			evoJunA,
			fatJulCorp,
			perJulCorp,
			fatJulLoja,
			perJulLoja,
			fatJulGrup,
			perJulGrup,
			fatJul,
			evoJul,
			evoJulA,
			fatAgoCorp,
			perAgoCorp,
			fatAgoLoja,
			perAgoLoja,
			fatAgoGrup,
			perAgoGrup,
			fatAgo,
			evoAgo,
			evoAgoA,
			fatSetCorp,
			perSetCorp,
			fatSetLoja,
			perSetLoja,
			fatSetGrup,
			perSetGrup,
			fatSet,
			evoSet,
			evoSetA,
			fatOutCorp,
			perOutCorp,
			fatOutLoja,
			perOutLoja,
			fatOutGrup,
			perOutGrup,
			fatOut,
			evoOut,
			evoOutA,
			fatNovCorp,
			perNovCorp,
			fatNovLoja,
			perNovLoja,
			fatNovGrup,
			perNovGrup,
			fatNov,
			evoNov,
			evoNovA,
			fatDezCorp,
			perDezCorp,
			fatDezLoja,
			perDezLoja,
			fatDezGrup,
			perDezGrup,
			fatDez,
			evoDez,
			evoDezA
		FROM faturamento_mensal_ano_evolucao;

END TRY
--	Lógica de tratamento de erros: 
--	Recuperar detalhes do erro usando funções do sistema.
BEGIN CATCH
    -- Tratar ou logar o erro
	SELECT
		ERROR_NUMBER() AS ErrorNumber,
		ERROR_SEVERITY() AS ErrorSeverity,
		ERROR_STATE() AS ErrorState,
		ERROR_PROCEDURE() AS ErrorProcedure,
		ERROR_LINE() AS ErrorLine,
		ERROR_MESSAGE() AS ErrorMessage;
    
END CATCH

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END