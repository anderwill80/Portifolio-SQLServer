/*
====================================================================================================================================================================================
WREL170 - Acompanhamento Anual de Vendas Evolucao das empresas do grupo BMPT
- Permite visualizar a evolucao das vendas durante os 12 meses do ano, conforme o periodo selecionado;
- Permite selecionar quais empresas serao contabilizadas, conectando remotamente via linkedServer;
- Permite selecionar para qual departamento mostrara os faturamentos, corporativo, loja ou grupo;

Obs.:	- Relatorio devera ser executado apenas pela gerencia;
		- A execucao provavelmente sera demorada, conforme periodo informado, pois ira buscar faturamento nas empresas, futuramente poderemos deixar gravado 
		uma tabela com esses dados ja calculados, sendo alimentada diariamente junto com a rotina do DWVendas;
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================10/04/2025 WILLIAM
31/03/2026 WILLIAM
	- Alteracao nos parametros da SP [usp_Check_LinkedServer];
17/03/2026 WILLIAM
	- Aumento da precisacao dos atributos referentes a evolucao, de decimal(7,2) para decimal(8,2);
16/03/2026 WILLIAM
	- Inclusao de colunas com porcentagem que cada grupo de faturamento representa no total, corporativo, loja e grupo para cada mes;
13/03/2026 WILLIAM
	- Acrescimo de verificacao se o linked server esta ONLINE, utilizando uma nova SP  [usp_Check_LinkedServer];
12/03/2026 WILLIAM
	- Criacao
====================================================================================================================================================================================
*/
--CREATE PROC [dbo].[usp_RS_WREL170_AcompanhamentoAnualVendas_EvolucaoGrupoBMPT]
ALTER PROC [dbo].[usp_RS_WREL170_AcompanhamentoAnualVendas_EvolucaoGrupoBMPT]
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
			@linkedExists bit, @linkedConnected bit, @linkedServerDate datetime;
			 
-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @pEmpCod	
	SET @dataDe = (SELECT ISNULL(@pDataDe, '17530101'));
	SET @dataAte = (SELECT ISNULL(@pDataAte, GETDATE() - 1));
	SET @empresas = UPPER(@pEmpresas);
	SET @contabiliza = UPPER(@pContabiliza);

	SET @EmpresaLocalCNPJ = (SELECT TOP 1 RTRIM(LTRIM(EMPCGC)) AS  EMPCGC FROM TBS023 (NOLOCK) WHERE EMPCOD = @codigoEmpresa)
	
	-- Define o nome da empresa que esta executando o relatorio, para a tabela final
	SET @EmpresaLocalSigla =
	CASE
		WHEN @EmpresaLocalCNPJ = '05118717000156' then 'BB'
		WHEN @EmpresaLocalCNPJ = '52080207000117' then 'MI'
		WHEN @EmpresaLocalCNPJ = '44125185000136' then 'PY'
		WHEN @EmpresaLocalCNPJ = '41952080000162' then 'WP'
		WHEN @EmpresaLocalCNPJ = '65069593000198' then 'TM'
		WHEN @EmpresaLocalCNPJ = '65069593000350' then 'TD'	-- A principio nao iremos processar CD, pois lá não existe vendas
		WHEN @EmpresaLocalCNPJ = '65069593000279' then 'TT'				
	END
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	

	-- Cria a tabela temporaria para obter os registros de cada empresa
	IF OBJECT_ID('tempdb.dbo.#TABELAFINAL') IS NOT NULL
		DROP TABLE #TABELAFINAL;

	CREATE TABLE #TABELAFINAL(
	[empresa] varchar(30),
	[ano] [int],
	[fatAno] [decimal](19, 4),
	[evoAno] [decimal](8, 2),
	[mediaMensal] [decimal](19, 4),
	[fatJanCorp] [decimal](19, 4),
	[perJanCorp] [decimal](7, 2),
	[fatJanLoja] [decimal](19, 4),
	[perJanLoja] [decimal](7, 2),
	[fatJanGrup] [decimal](19, 4),
	[perJanGrup] [decimal](7, 2),
	[fatJan] [decimal](19, 4),
	[evoJan] [decimal](8, 2),
	[evoJanA] [decimal](8, 2),
	[fatFevCorp] [decimal](19, 4),
	[perFevCorp] [decimal](7, 2),
	[fatFevLoja] [decimal](19, 4),
	[perFevLoja] [decimal](7, 2),
	[fatFevGrup] [decimal](19, 4),
	[perFevGrup] [decimal](7, 2),
	[fatFev] [decimal](19, 4),
	[evoFev] [decimal](8, 2),
	[evoFevA] [decimal](8, 2),
	[fatMarCorp] [decimal](19, 4),
	[perMarCorp] [decimal](7, 2),
	[fatMarLoja] [decimal](19, 4),
	[perMarLoja] [decimal](7, 2),
	[fatMarGrup] [decimal](19, 4),
	[perMarGrup] [decimal](7, 2),
	[fatMar] [decimal](19, 4),
	[evoMar] [decimal](8, 2),
	[evoMarA] [decimal](8, 2),
	[fatAbrCorp] [decimal](19, 4),
	[perAbrCorp] [decimal](7, 2),
	[fatAbrLoja] [decimal](19, 4),
	[perAbrLoja] [decimal](7, 2),
	[fatAbrGrup] [decimal](19, 4),
	[perAbrGrup] [decimal](7, 2),
	[fatAbr] [decimal](19, 4),
	[evoAbr] [decimal](8, 2),
	[evoAbrA] [decimal](8, 2),
	[fatMaiCorp] [decimal](19, 4),
	[perMaiCorp] [decimal](7, 2),
	[fatMaiLoja] [decimal](19, 4),
	[perMaiLoja] [decimal](7, 2),
	[fatMaiGrup] [decimal](19, 4),
	[perMaiGrup] [decimal](7, 2),
	[fatMai] [decimal](19, 4),
	[evoMai] [decimal](8, 2),
	[evoMaiA] [decimal](8, 2),
	[fatJunCorp] [decimal](19, 4),
	[perJunCorp] [decimal](7, 2),
	[fatJunLoja] [decimal](19, 4),
	[perJunLoja] [decimal](7, 2),
	[fatJunGrup] [decimal](19, 4),
	[perJunGrup] [decimal](7, 2),
	[fatJun] [decimal](19, 4),
	[evoJun] [decimal](8, 2),
	[evoJunA] [decimal](8, 2),
	[fatJulCorp] [decimal](19, 4),
	[perJulCorp] [decimal](7, 2),
	[fatJulLoja] [decimal](19, 4),
	[perJulLoja] [decimal](7, 2),
	[fatJulGrup] [decimal](19, 4),
	[perJulGrup] [decimal](7, 2),
	[fatJul] [decimal](19, 4),
	[evoJul] [decimal](8, 2),
	[evoJulA] [decimal](8, 2),
	[fatAgoCorp] [decimal](19, 4),
	[perAgoCorp] [decimal](7, 2),
	[fatAgoLoja] [decimal](19, 4),
	[perAgoLoja] [decimal](7, 2),
	[fatAgoGrup] [decimal](19, 4),
	[perAgoGrup] [decimal](7, 2),
	[fatAgo] [decimal](19, 4),
	[evoAgo] [decimal](8, 2),
	[evoAgoA] [decimal](8, 2),
	[fatSetCorp] [decimal](19, 4),
	[perSetCorp] [decimal](7, 2),
	[fatSetLoja] [decimal](19, 4),
	[perSetLoja] [decimal](7, 2),
	[fatSetGrup] [decimal](19, 4),
	[perSetGrup] [decimal](7, 2),
	[fatSet] [decimal](19, 4),
	[evoSet] [decimal](8, 2),
	[evoSetA] [decimal](8, 2),
	[fatOutCorp] [decimal](19, 4),
	[perOutCorp] [decimal](7, 2),
	[fatOutLoja] [decimal](19, 4),
	[perOutLoja] [decimal](7, 2),
	[fatOutGrup] [decimal](19, 4),
	[perOutGrup] [decimal](7, 2),
	[fatOut] [decimal](19, 4),
	[evoOut] [decimal](8, 2),
	[evoOutA] [decimal](8, 2),
	[fatNovCorp] [decimal](19, 4),
	[perNovCorp] [decimal](7, 2),
	[fatNovLoja] [decimal](19, 4),
	[perNovLoja] [decimal](7, 2),
	[fatNovGrup] [decimal](19, 4),
	[perNovGrup] [decimal](7, 2),
	[fatNov] [decimal](19, 4),
	[evoNov] [decimal](8, 2),
	[evoNovA] [decimal](8, 2),
	[fatDezCorp] [decimal](19, 4),
	[perDezCorp] [decimal](7, 2),
	[fatDezLoja] [decimal](19, 4),
	[perDezLoja] [decimal](7, 2),
	[fatDezGrup] [decimal](19, 4),
	[perDezGrup] [decimal](7, 2),
	[fatDez] [decimal](19, 4),
	[evoDez] [decimal](8, 2),
	[evoDezA] [decimal](8, 2)
	);
	---------------------------------------------------------------------------------------
	-- Grava dados de faturamento da empresa local que esta executando o relatorio
	---------------------------------------------------------------------------------------

	-- verifica se a empresa local foi selecionada no filtro
	IF PATINDEX('%' + @EmpresaLocalSigla + '%', @empresas) > 0  
	BEGIN
		INSERT INTO #TABELAFINAL
		EXEC [usp_Get_DWVendas_FaturamentoAnual] @codigoEmpresa, @dataDe, @dataAte, @contabiliza;
	END
			
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
			INSERT INTO #TABELAFINAL
			EXEC bb.SIBD2.dbo.[usp_Get_DWVendas_FaturamentoAnual] 2, @dataDe, @dataAte, @contabiliza;			
		END
		ELSE
		BEGIN
			INSERT INTO #TABELAFINAL
			SELECT 'BESTBAG <SEM CONEXAO>',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		END;
	END;

	-- MISASPEL
	IF (PATINDEX('%MI%', @empresas) > 0 AND @EmpresaLocalCNPJ != '52080207000117')
	BEGIN
		-- Verifica se linkedserver está ONLINE
		EXEC usp_Check_LinkedServer 'mi', @linkedConnected OUT;

		IF @linkedConnected = 1
		BEGIN
			INSERT INTO #TABELAFINAL
			EXEC py.SIBD3.dbo.[usp_Get_DWVendas_FaturamentoAnual] 1, @dataDe, @dataAte, @contabiliza;			
		END
		ELSE
		BEGIN
			INSERT INTO #TABELAFINAL
			SELECT 'MISASPEL <SEM CONEXAO>',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		END;
	END;

	-- PAPELYNA
	IF (PATINDEX('%PY%', @empresas) > 0 AND @EmpresaLocalCNPJ != '44125185000136')			
	BEGIN
		-- Verifica se linkedserver está ONLINE
		EXEC usp_Check_LinkedServer 'py', @linkedConnected OUT;

		IF @linkedConnected = 1
		BEGIN
			INSERT INTO #TABELAFINAL
			EXEC py.SIBD.dbo.[usp_Get_DWVendas_FaturamentoAnual] 1, @dataDe, @dataAte, @contabiliza;			
		END
		ELSE
		BEGIN
			INSERT INTO #TABELAFINAL
			SELECT 'PAPELYNA <SEM CONEXAO>',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		END;
	END;

	-- WINPACK
	IF (PATINDEX('%WP%', @empresas) > 0 AND @EmpresaLocalCNPJ != '41952080000162')
	BEGIN
		-- Verifica se linkedserver está ONLINE
		EXEC usp_Check_LinkedServer 'py', @linkedConnected OUT;

		IF @linkedConnected = 1
		BEGIN
			INSERT INTO #TABELAFINAL
			EXEC py.SIBD4.dbo.[usp_Get_DWVendas_FaturamentoAnual] 1, @dataDe, @dataAte, @contabiliza;			
		END
		ELSE
		BEGIN
			INSERT INTO #TABELAFINAL
			SELECT 'WINPACK <SEM CONEXAO>',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		END;
	END;

	-- TANBY MATRIZ
	IF (PATINDEX('%TM%', @empresas) > 0 AND @EmpresaLocalCNPJ != '65069593000198')
	BEGIN
		-- Verifica se linkedserver está ONLINE
		EXEC usp_Check_LinkedServer 'tm', @linkedConnected OUT;

		IF @linkedConnected = 1
		BEGIN
			INSERT INTO #TABELAFINAL
			EXEC tm.SIBD.dbo.[usp_Get_DWVendas_FaturamentoAnual] 1, @dataDe, @dataAte, @contabiliza;
		END
		ELSE
		BEGIN
			INSERT INTO #TABELAFINAL
			SELECT 'TANBY MATRIZ <SEM CONEXAO>',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		END;
	END;

	-- TANBY TAUBATE
	IF (PATINDEX('%TT%', @empresas) > 0 AND @EmpresaLocalCNPJ != '65069593000279')
	BEGIN
		-- Verifica se linkedserver está ONLINE
		EXEC usp_Check_LinkedServer 'tt', @linkedConnected OUT;

		IF @linkedConnected = 1
		BEGIN
			INSERT INTO #TABELAFINAL
			EXEC tt.SIBD.dbo.[usp_Get_DWVendas_FaturamentoAnual] 1, @dataDe, @dataAte, @contabiliza;
		END
		ELSE
		BEGIN
			INSERT INTO #TABELAFINAL
			SELECT 'TANBY TAUBATE <SEM CONEXAO>',0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
		END;
	END;
/**/			
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final
	SELECT
		*
	FROM #TABELAFINAL
	ORDER BY
		empresa;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END