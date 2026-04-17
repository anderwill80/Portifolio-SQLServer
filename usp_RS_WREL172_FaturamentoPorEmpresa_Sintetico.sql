/*
====================================================================================================================================================================================
WREL172 - Faturamento por empresa do grupo BMPT - Sintetico
- Permite visualizar as vendas liquidas(vendido - devolucao), durante conforme o periodo selecionado;
- Permite selecionar quais empresas serao contabilizadas, conectando remotamente via linkedServer;
- Permite selecionar para qual segmento mostrara os faturamentos, corporativo, loja ou grupo;

Obs.:	- Relatorio devera ser executado apenas pela gerencia;		
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================10/04/2025 WILLIAM
14/04/2026 WILLIAM
	- Uso da SP [usp_Get_CNPJSigla_EmpresaBMPT] para obter o CNPJ e a sigla da empresa local, ao invés de usar um CASE, para facilitar a manutenção futura;
31/03/2026 WILLIAM
	- Alteracao nos parametros da SP [usp_Check_LinkedServer];
25/03/2026 WILLIAM
	- Criacao
====================================================================================================================================================================================
*/
--CREATE PROC [dbo].[usp_RS_WREL172_FaturamentoPorEmpresa_Sintetico]
ALTER PROC [dbo].[usp_RS_WREL172_FaturamentoPorEmpresa_Sintetico]
	@pEmpCod smallint,
	@pDataDe date = NULL, 
	@pDataAte date = NULL, 
	@pEmpresas VARCHAR(50) = '',
	@pContabiliza VARCHAR(10) = 'C,L'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @dataDe date, @dataAte date, @empresas VARCHAR(50), @contabiliza VARCHAR(10),
			@EmpresaLocalCNPJ VARCHAR(20), @EmpresaLocalSigla VARCHAR(2),
			@linkedConnected bit;
			 
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod	
	SET @dataDe = (SELECT ISNULL(@pDataDe, '17530101'));
	SET @dataAte = (SELECT ISNULL(@pDataAte, GETDATE() - 1));
	SET @empresas = UPPER(@pEmpresas);
	SET @contabiliza = UPPER(@pContabiliza);

	-- Obtem a sigla da empresa local, para ser utilizada na tabela final
	EXEC [usp_Get_CNPJSigla_EmpresaBMPT] @codigoEmpresa, @EmpresaLocalCNPJ OUT, @EmpresaLocalSigla OUT;	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	

	-- Cria a tabela temporaria para obter os registros de cada empresa
	IF OBJECT_ID('tempdb.dbo.#FATURAMENTO') IS NOT NULL
		DROP TABLE #FATURAMENTO;						

	CREATE TABLE #FATURAMENTO(
		[empresa] varchar(30),
		[segmento] varchar(15),
		[custoTotalLiq] [decimal](19, 4),
		[valorTotalLiq] [decimal](19, 4),
		[perSobreTotal] [decimal](7, 2),
		[margemLucro] [decimal](7, 2),
		[ticketMedio] [decimal](19, 4),
		[valorTotalDev] [decimal](19, 4),
		[perSobreTotalDev] [decimal](7, 2),
		[qtdNotas] [int],		
		[valorNotas] [decimal](19, 4),
		[qtdCupons] [int],
		[valorCupons] [decimal](19, 4),
		[qtdDocumentos] [int],		
		[custoTotalEmp] [decimal](19, 4),
		[valorTotalEmp] [decimal](19, 4),
		[valorTotalDevEmp] [decimal](19, 4),
		[qtdNotasEmp] [int],
		[valorNotasEmp] [decimal](19, 4),
		[qtdCuponsEmp] [int],
		[valorCuponsEmp] [decimal](19, 4),
		[qtdDocsEmp] [int],
		[margemLucroEmp] [decimal](7, 2),
		[ticketMedioEmp] [decimal](19, 4)
	);
	---------------------------------------------------------------------------------------
	-- Grava dados de faturamento da empresa local que esta executando o relatorio
	---------------------------------------------------------------------------------------

	-- verifica se a empresa local foi selecionada no filtro
	IF PATINDEX('%' + @EmpresaLocalSigla + '%', @empresas) > 0  
	BEGIN
		INSERT INTO #FATURAMENTO
		EXEC [usp_Get_DWVendas_FaturamentoSintetico] @codigoEmpresa, @dataDe, @dataAte, @contabiliza;
	END
-- TESTE	
--	INSERT INTO #FATURAMENTO
--	select 'WINPACK', 'Corporativo', 80, 100, 100, 20, 50, 0, 0, 2, 0, 2, 80, 100, 0, 2, 0, 2, 20, 50;
-- TESTE
	---------------------------------------------------------------------------------------
	-- Verifica qual empresa remota sera obtida os dados de faturamento
	---------------------------------------------------------------------------------------
	
	-- BESTBAG
	IF (PATINDEX('%BB%', @empresas) > 0 AND @EmpresaLocalCNPJ != '05118717000156')
	BEGIN
		-- Verifica se linkedserver está ONLINE
		EXEC usp_Check_LinkedServer 'bb', @linkedConnected OUT;

		IF @linkedConnected = 1
		BEGIN
			INSERT INTO #FATURAMENTO
			EXEC bb.SIBD2.dbo.[usp_Get_DWVendas_FaturamentoSintetico] 2, @dataDe, @dataAte, @contabiliza;			
		END
		ELSE
		BEGIN
			INSERT INTO #FATURAMENTO
			SELECT 'BESTBAG <SEM CONEXAO>', '', 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0;
		END;
	END;

	-- MISASPEL
	IF (PATINDEX('%MI%', @empresas) > 0 AND @EmpresaLocalCNPJ != '52080207000117')
	BEGIN
		-- Verifica se linkedserver está ONLINE
		EXEC usp_Check_LinkedServer 'mi', @linkedConnected OUT;

		IF @linkedConnected = 1
		BEGIN
			INSERT INTO #FATURAMENTO
			EXEC py.SIBD3.dbo.[usp_Get_DWVendas_FaturamentoSintetico] 1, @dataDe, @dataAte, @contabiliza;			
		END
		ELSE
		BEGIN
			INSERT INTO #FATURAMENTO
			SELECT 'MISASPEL <SEM CONEXAO>', '', 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0;
		END;
	END;

	-- PAPELYNA
	IF (PATINDEX('%PY%', @empresas) > 0 AND @EmpresaLocalCNPJ != '44125185000136')			
	BEGIN
		-- Verifica se linkedserver está ONLINE
		EXEC usp_Check_LinkedServer 'py', @linkedConnected OUT;

		IF @linkedConnected = 1
		BEGIN
			INSERT INTO #FATURAMENTO
			EXEC py.SIBD.dbo.[usp_Get_DWVendas_FaturamentoSintetico] 1, @dataDe, @dataAte, @contabiliza;			
		END
		ELSE
		BEGIN
			INSERT INTO #FATURAMENTO
			SELECT 'PAPELYNA <SEM CONEXAO>', '', 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0;
		END;
	END;

	-- WINPACK
	IF (PATINDEX('%WP%', @empresas) > 0 AND @EmpresaLocalCNPJ != '41952080000162')
	BEGIN
		-- Verifica se linkedserver está ONLINE
		EXEC usp_Check_LinkedServer 'py', @linkedConnected OUT;

		IF @linkedConnected = 1
		BEGIN
			INSERT INTO #FATURAMENTO
			EXEC py.SIBD4.dbo.[usp_Get_DWVendas_FaturamentoSintetico] 1, @dataDe, @dataAte, @contabiliza;			
		END
		ELSE
		BEGIN
			INSERT INTO #FATURAMENTO
			SELECT 'WINPACK <SEM CONEXAO>', '', 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0;
		END;
	END;

	-- TANBY MATRIZ
	IF (PATINDEX('%TM%', @empresas) > 0 AND @EmpresaLocalCNPJ != '65069593000198')
	BEGIN
		-- Verifica se linkedserver está ONLINE
		EXEC usp_Check_LinkedServer 'tm', @linkedConnected OUT;

		IF @linkedConnected = 1
		BEGIN
			INSERT INTO #FATURAMENTO
			EXEC tm.SIBD.dbo.[usp_Get_DWVendas_FaturamentoSintetico] 1, @dataDe, @dataAte, @contabiliza;
		END
		ELSE
		BEGIN
			INSERT INTO #FATURAMENTO
			SELECT 'TANBY MATRIZ <SEM CONEXAO>', '', 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0;
		END;
	END;

	-- TANBY TAUBATE
	IF (PATINDEX('%TT%', @empresas) > 0 AND @EmpresaLocalCNPJ != '65069593000279')
	BEGIN
		-- Verifica se linkedserver está ONLINE
		EXEC usp_Check_LinkedServer 'tt', @linkedConnected OUT;

		IF @linkedConnected = 1
		BEGIN
			INSERT INTO #FATURAMENTO
			EXEC tt.SIBD.dbo.[usp_Get_DWVendas_FaturamentoSintetico] 1, @dataDe, @dataAte, @contabiliza;
		END
		ELSE
		BEGIN
			INSERT INTO #FATURAMENTO
			SELECT 'TANBY TAUBATE <SEM CONEXAO>', '', 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0, 0, 0, 0;
		END;
	END;
			
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os totais gerais para calular ticket medio e margem lucro geral;
	;WITH
	faturmento_geral AS(
	SELECT
		*,
		CAST(SUM(custoTotalLiq) OVER() AS DECIMAL(19,4)) AS custoTotalGeral,
		CAST(SUM(valorTotalLiq) OVER() AS DECIMAL(19,4)) AS valorTotalGeral,
		CAST(SUM(valorTotalDev) OVER() AS DECIMAL(19,4)) AS valorTotalDevGeral,
		CAST(SUM(qtdNotas) OVER() AS INT) AS qtdNotasGeral,
		CAST(SUM(valorNotas) OVER() AS DECIMAL(19,4)) AS valorNotasGeral,
		CAST(SUM(qtdCupons) OVER() AS INT) AS qtdCuponsGeral,
		CAST(SUM(valorCupons) OVER() AS DECIMAL(19,4)) AS valorCuponsGeral,
		CAST(SUM(qtdDocumentos) OVER() AS INT) AS qtdDocsGeral
	FROM #FATURAMENTO
	)	
	-- Tabela final, calculando ticket medio e margem de lucro geral
	SELECT
		*,
		CAST(ISNULL((valorTotalGeral - custoTotalGeral) / NULLIF(valorTotalGeral, 0), 0) * 100 AS DECIMAL(7,2)) AS margemLucroGeral,
		CAST(ISNULL(valorTotalGeral / NULLIF(qtdDocsGeral, 0), 0) AS DECIMAL(19,4)) AS ticketMedioGeral
	FROM faturmento_geral
	ORDER BY
		empresa;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END