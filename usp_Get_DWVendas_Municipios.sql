/*
====================================================================================================================================================================================
Obtem os municipios que houve vendas da tabela "DWVendas";
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
16/02/2026 WILLIAM
	- Criacao;
====================================================================================================================================================================================
*/
CREATE PROC [dbo].[usp_Get_DWVendas_Municipios]
--ALTER PROC [dbo].[usp_Get_DWVendas_Municipios]
	@empcod smallint,
	@pdataDe date = null,
	@pdataAte date = null
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @dataEmissao_De date, @dataEmissao_Ate date, @empresaTBS067 smallint;

-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @dataEmissao_De = (SELECT ISNULL(@pdataDe, '17530101'));
	SET @dataEmissao_Ate = (SELECT ISNULL(@pdataAte, GETDATE() - 1));

-- Obtem empresa da tabela    
    EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS067', @empresaTBS067 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ 

    -- Agrupa municipios que houve vendas
    SELECT
        RTRIM(municipio) AS municipio, 
        uf + ' - ' + RTRIM(municipio) AS ufmunicipio
    FROM    DWVendas (NOLOCK)
    WHERE 
        codigoEmpresa = @empresaTBS067 AND 
        codigoCliente > 0 AND 
        data BETWEEN @dataEmissao_De AND @dataEmissao_Ate
    GROUP BY codigoEmpresa, uf, municipio
    ORDER BY codigoEmpresa, uf, municipio
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ 

END