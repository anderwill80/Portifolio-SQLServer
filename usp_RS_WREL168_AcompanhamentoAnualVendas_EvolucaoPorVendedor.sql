/*
====================================================================================================================================================================================
WREL168 - Evolucao de vendas por vendedor: Permite visualizar a evolucao das vendas durante os 12 meses do ano, conforme os anos selecionados;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================10/04/2025 WILLIAM
09/03/2026 WILLIAM
	- Correcao aumentando a precicao dos atributos de evolucao em % de decimal(6,2) para decimal(7,2), tem caso com mais de 15.700%, ou seja 5 digitos parte inteira;
	- Utilizacao de blocos "BEGIN TRY" e "BEGIN CATCH" para captura mais detalhada de erros;
03/03/2026 WILLIAM
	- Correcao aumentando a precicao dos atributos de evolucao em % de decimal(5,2) para decimal(6,2), tem caso com mais de 2000%, ou seja 4 digitos parte inteira;
24/02/2026 WILLIAM
	- Criacao
====================================================================================================================================================================================
*/
--ALTER PROC [dbo].[usp_RS_WREL168_AcompanhamentoAnualVendas_EvolucaoPorVendedor_DEBUG]
ALTER PROC [dbo].[usp_RS_WREL168_AcompanhamentoAnualVendas_EvolucaoPorVendedor] 
	@pEmpCod smallint,
	@pDataDe date, 
	@pDataAte date, 
	@pCodigoVendedor varchar(200) = '', 
	@pCodigoGrupoVendedores varchar(100) = '',
	@pGrupoBMPT char(1) = 'N'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @data_De date, @data_Ate date, @VENCOD varchar(500), @GruposVendedores varchar(100), @GrupoBMPT char(1),
			@contabiliza char(10);
			 
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod	
	SET @data_De = (SELECT ISNULL(@pDataDe, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@pDataAte, GETDATE() - 1));
	SET @VENCOD = @pCodigoVendedor;
	SET @GruposVendedores = @pCodigoGrupoVendedores;	
	SET @GrupoBMPT = UPPER(@pGrupoBMPT);

-- Atribuicoes internas
	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C,L', '');	
	
/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoVendedor = @VENCOD,
		@pcodigoGrupoVendedor = @GruposVendedores,		
		@pcontabiliza = @contabiliza,
		@ptipoDocumento = 'N';

/***********************************************************************************************************************************************************************************
	Obter as devolucoes da tabela DWDevolucaoVendas
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoVendedor = @VENCOD,
		@pcodigoGrupoVendedor = @GruposVendedores,		
		@pcontabiliza = @contabiliza		

--	 SELECT * FROM ##DWVendas;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
           
	-- Utilizaremos CTE para facilitar a codificacao...
	;WITH
		-- Vendas agrupadas por ano, mes e vendedor
		vendas_ano_mes_vendedor AS(		
		SELECT 
			codigoVendedor,	
			YEAR(data) AS ano,
			MONTH(data) AS mes,
			SUM(valorTotal) AS faturamento
		FROM ##DWVendas
		WHERE codigoVendedor > 0

		GROUP BY 
			codigoVendedor,
			YEAR(data), 
			MONTH(data)			
		),
--		SELECT * from vendas_ano_mes_vendedor;
		
		-- Devolucoes agrupadas por ano, mes e vendedor
		devolucoes_ano_mes_vendedor AS(		
		SELECT		
			codigoVendedor,	
			YEAR(data) AS ano,
			MONTH(data) AS mes,
			SUM(valorTotal) AS devolucao
		FROM ##DWDevolucaoVendas
		WHERE codigoVendedor > 0

		GROUP BY 
			codigoVendedor,
			YEAR(data), 
			MONTH(data)	
		),
		--SELECT * from  devolucoes_ano_mes_vendedor;

		-- Abate devolucao caso exista
		faturamento AS(
		SELECT 
			v.codigoVendedor,
			v.ano,
			v.mes,
			faturamento - ISNULL(devolucao, 0) AS faturamento
		FROM vendas_ano_mes_vendedor v
		LEFT JOIN devolucoes_ano_mes_vendedor d ON 
			d.codigoVendedor = v.codigoVendedor AND
			d.ano = v.ano AND
			d.mes = v.mes
		),
		--SELECT * from faturamento;
		
		-- Uso da clausula "PIVOT...FOR" para transpor as linhas em colunas(janeiro, fevereiro, etc)
		faturamento_pivoteada AS(		
		SELECT 		
			codigoVendedor,
			ISNULL(VENNOM, '') AS nomeVendedor,			
			ano,
			CAST(ISNULL([1], 0) AS DECIMAL(19, 4)) AS fatJan,
			CAST(ISNULL([2], 0) AS DECIMAL(19, 4)) AS fatFev,
			CAST(ISNULL([3], 0) AS DECIMAL(19, 4)) AS fatMar,
			CAST(ISNULL([4], 0) AS DECIMAL(19, 4)) AS fatAbr,
			CAST(ISNULL([5], 0) AS DECIMAL(19, 4)) AS fatMai,
			CAST(ISNULL([6], 0) AS DECIMAL(19, 4)) AS fatJun,
			CAST(ISNULL([7], 0) AS DECIMAL(19, 4)) AS fatJul,
			CAST(ISNULL([8], 0) AS DECIMAL(19, 4)) AS fatAgo,
			CAST(ISNULL([9], 0) AS DECIMAL(19, 4)) AS fatSet,
			CAST(ISNULL([10], 0) AS DECIMAL(19, 4)) AS fatOut,
			CAST(ISNULL([11], 0) AS DECIMAL(19, 4)) AS fatNov,
			CAST(ISNULL([12], 0) AS DECIMAL(19, 4)) AS fatDez
		FROM faturamento PIVOT (SUM(faturamento) FOR mes IN ([1],[2],[3],[4],[5],[6],[7],[8],[9],[10],[11],[12])) P
		LEFT JOIN TBS004 (NOLOCK) ON VENCOD = codigoVendedor
		),
		--SELECT * from faturamento_pivoteada;
		
		-- Total por ano...
		faturamento_anual AS(		
		SELECT 
			*,					
			CAST((fatJan + fatFev + fatMar + fatAbr + fatMai + fatJun + fatJul + fatAgo + fatSet + fatOut + fatNov + fatDez) AS DECIMAL(19,4)) AS totalAno,
			CAST(SIGN(fatJan) + SIGN(fatFev) + SIGN(fatMar) + SIGN(fatAbr) + SIGN(fatMai) + SIGN(fatJun) +
			SIGN(fatJul) + SIGN(fatAgo) + SIGN(fatSet) + SIGN(fatOut) + SIGN(fatNov) + SIGN(fatDez) AS INT) AS qtdMeses

		FROM faturamento_pivoteada
		),
		--select * from faturamento_anual;

		-- Obtem o faturamento do ano anterior via "WINDOWS FUNCTION" LAG() OVER()
		faturamento_anual_anterior AS(
		SELECT 	
			*,
			CAST((LAG(fatJan, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatJanA,
			CAST((LAG(fatFev, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatFevA,
			CAST((LAG(fatMar, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatMarA,

			CAST((LAG(fatAbr, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatAbrA,
			CAST((LAG(fatMai, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatMaiA,
			CAST((LAG(fatJun, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatJunA,

			CAST((LAG(fatJul, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatJulA,
			CAST((LAG(fatAgo, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatAgoA,
			CAST((LAG(fatSet, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatSetA,

			CAST((LAG(fatOut, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatOutA,
			CAST((LAG(fatNov, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatNovA,
			CAST((LAG(fatDez, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS fatDezA,

			CAST((LAG(totalAno, 1, 0) OVER (PARTITION BY codigoVendedor ORDER BY ano)) AS DECIMAL(19, 4)) AS totalAnoA
		FROM faturamento_anual
		),
		 --SELECT * FROM faturamento_anual_anterior;

		-- Com os faturamentos atuais e anteriores do ano e mes, 
		-- calcula a evolucao mensal referente ao mes passado e o mesmo mes ano anterior em %
		faturamento_anual_evolucao AS(
		SELECT			
			*,
			CAST(ISNULL((NULLIF(fatJan, 0) - fatDezA) / NULLIF(fatDezA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoJan,
			CAST(ISNULL((NULLIF(fatJan, 0) - fatJanA) / NULLIF(fatJanA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoJanA,

			CAST(ISNULL((NULLIF(fatFev, 0) - fatJan) / NULLIF(fatJan, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoFev,
			CAST(ISNULL((NULLIF(fatFev, 0) - fatFevA) / NULLIF(fatFevA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoFevA,

			CAST(ISNULL((NULLIF(fatMar, 0) - fatFev) / NULLIF(fatFev, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoMar,
			CAST(ISNULL((NULLIF(fatMar, 0) - fatMarA) / NULLIF(fatMarA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoMarA,

			CAST(ISNULL((NULLIF(fatAbr, 0) - fatMar) / NULLIF(fatMar, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoAbr,
			CAST(ISNULL((NULLIF(fatAbr, 0) - fatAbrA) / NULLIF(fatAbrA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoAbrA,

			CAST(ISNULL((NULLIF(fatMai, 0) - fatAbr) / NULLIF(fatAbr, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoMai,
			CAST(ISNULL((NULLIF(fatMai, 0) - fatMaiA) / NULLIF(fatMaiA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoMaiA,

			CAST(ISNULL((NULLIF(fatJun, 0) - fatMai) / NULLIF(fatMai, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoJun,
			CAST(ISNULL((NULLIF(fatJun, 0) - fatJunA) / NULLIF(fatJunA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoJunA,
			
			CAST(ISNULL((NULLIF(fatJul, 0) - fatJun) / NULLIF(fatJun, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoJul,
			CAST(ISNULL((NULLIF(fatJul, 0) - fatJulA) / NULLIF(fatJulA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoJulA,

			CAST(ISNULL((NULLIF(fatAgo, 0) - fatJul) / NULLIF(fatJul, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoAgo,
			CAST(ISNULL((NULLIF(fatAgo, 0) - fatAgoA) / NULLIF(fatAgoA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoAgoA,

			CAST(ISNULL((NULLIF(fatSet, 0) - fatAgo) / NULLIF(fatAgo, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoSet,
			CAST(ISNULL((NULLIF(fatSet, 0) - fatSetA) / NULLIF(fatSetA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoSetA,

			CAST(ISNULL((NULLIF(fatOut, 0) - fatSet) / NULLIF(fatSet, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoOut,
			CAST(ISNULL((NULLIF(fatOut, 0) - fatOutA) / NULLIF(fatOutA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoOutA,

			CAST(ISNULL((NULLIF(fatNov, 0) - fatOut) / NULLIF(fatOut, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoNov,
			CAST(ISNULL((NULLIF(fatNov, 0) - fatNovA) / NULLIF(fatNovA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoNovA,

			CAST(ISNULL((NULLIF(fatDez, 0) - fatNov) / NULLIF(fatNov, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoDez,
			CAST(ISNULL((NULLIF(fatDez, 0) - fatDezA) / NULLIF(fatDezA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoDezA,

			CAST(ISNULL((totalAno - totalAnoA) / NULLIF(totalAnoA, 0) * 100., 0) AS DECIMAL(7, 2)) AS evoAno,

			CAST(totalAno / NULLIF(qtdMeses, 0) AS DECIMAL(19, 4)) AS mediaMensal
		FROM faturamento_anual_anterior
		)	
		-- SELECT sum(totalAno) FROM faturamento_anual_evolucao;
		
		-- Tabela final, apenas para reorganizar as colunas de forma mais intuitiva de entender o resultado
		
		SELECT 
			codigoVendedor,
			nomeVendedor,
			ano,
			totalAno,
			mediaMensal,
			evoAno,

			fatJan,
			evoJan,
			evoJanA,
			
			fatFev,
			evoFev,
			evoFevA,

			fatMar,
			evoMar,
			evoMarA,

			fatAbr,
			evoAbr,
			evoAbrA,

			fatMai,
			evoMai,
			evoMaiA,

			fatJun,
			evoJun,
			evoJunA,

			fatJul,
			evoJul,
			evoJulA,

			fatAgo,
			evoAgo,
			evoAgoA,

			fatSet,
			evoSet,
			evoSetA,

			fatOut,
			evoOut,
			evoOutA,

			fatNov,
			evoNov,
			evoNovA,

			fatDez,
			evoDez,
			evoDezA			
			
		FROM faturamento_anual_evolucao;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais criadas pelas SPs de vendas e devolucao
	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END