/*
====================================================================================================================================================================================
WREL125 - Solicitacao pagamentos fornecedores
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
18/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parametros de entrada da SP;	
	- Uso de consultas dinamicas, juntamente com a SP "sp_executesql";
	- Inclusão de filtro pela empresa da tabela, usando a SP "usp_GetCodigoEmpresaTabela" irá atender empresas como ex.: MRE Ferramentas;
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_SomatoriosPedidosCompras]
--ALTER PROCEDURE [dbo].[usp_RS_SomatoriosPedidosCompras]
	@empcod smallint,
	@dataDe datetime,
	@dataAte datetime,
	@nomeDoFornecedor varchar(60)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS006 smallint, @empresaTBS045 smallint, @empresaTBS046 smallint,
			@PDCDATCAD_De datetime, @PDCDATCAD_Ate datetime, @FORNOM varchar(60),
			@cmdSQL nvarchar(MAX), @ParmDef nvarchar(500);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @PDCDATCAD_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @PDCDATCAD_Ate = (SELECT ISNULL(@dataAte, GETDATE()));
	SET @FORNOM = RTRIM(LTRIM(UPPER(@nomeDoFornecedor)));

-- Verificar se a tabela é compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS006', @empresaTBS006 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS045', @empresaTBS045 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS046', @empresaTBS046 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final
	SET @cmdSQL = N'
		SELECT 
			SUBSTRING(CONVERT(char(8),PDCDATCAD,112),1,4) as ''AnoDaEmissao'',
			SUBSTRING(CONVERT(char(8),PDCDATCAD,112),5,2) as ''MesDaEmissao'',
			SUBSTRING(CONVERT(char(8),PDCDATCAD,112),7,2) as ''DiaDaEmissao'',
			PDCNUM as ''NumeroDoPedido'',
			RTRIM(FORNOM)+ '' ('' + LTRIM(STR(TBS006.FORCOD,5)) + '')'' as ''NomeECodigoDoFornecedor'',
			ISNULL(RTRIM(COMNOM) + '' ('' + LTRIM(STR(TBS045.COMCOD,3)) + '')'', '''') as ''NomeECodigoDoComprador'',
			dbo.PDCTOTLIQ(PDCEMPCOD,PDCNUM) as ''TotalDoProduto'',
			dbo.PDCTOTBRU(PDCEMPCOD,PDCNUM) as ''TotalDoPedido'',
			dbo.PDCTOTENT(PDCEMPCOD,PDCNUM) as ''TotalJaEntregue'',
			dbo.PDCTOTRES(PDCEMPCOD,PDCNUM) as ''TotalResiduo'',
			dbo.PDCTOTIPI(PDCEMPCOD,PDCNUM) as ''TotalDoIPI'',
			dbo.PDCTOTST(PDCEMPCOD,PDCNUM) as ''TotalDaST'',
			PDCVALFRETOT as ''TotalDoFrete'',
			PDCVALSEGTOT as ''TotalDoSeguro'',
			PDCVALOUTTOT as ''TotalDeOutrasDespesas'',
			dbo.PDCVDDTOT(PDCEMPCOD,PDCNUM) as ''TotalDoDesconto''
		FROM TBS045 (NOLOCK) 
			RIGHT JOIN TBS006 (NOLOCK) on TBS006.FOREMPCOD = @empresaTBS006 AND TBS006.FORCOD=TBS045.FORCOD
			LEFT JOIN TBS046 (NOLOCK) on TBS046.COMEMPCOD = @empresaTBS046 AND TBS046.COMCOD=TBS045.COMCOD
		WHERE 
			PDCEMPCOD = @empresaTBS045
			AND PDCDATCAD BETWEEN @PDCDATCAD_De AND @PDCDATCAD_Ate'
		+
		IIF(@FORNOM = '', '', ' AND FORNOM LIKE @FORNOM')

	-- Prepara e executa a consulta dinamica
	SET @ParmDef = N'@empresaTBS006 smallint, @empresaTBS045 smallint, @empresaTBS046 smallint, @PDCDATCAD_De datetime, @PDCDATCAD_Ate datetime, @FORNOM varchar(60)'
	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS006, @empresaTBS045, @empresaTBS046, @PDCDATCAD_De, @PDCDATCAD_Ate, @FORNOM

END