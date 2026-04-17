/*
====================================================================================================================================================================================
Resumo de vendas GZ | SubRelatorio - chamado por dentro do Faturamento NFS X CUPOM
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
08/04/2025 WILLIAM
	- Troca do parametro "@pSomenteCupom = 'S'" pelo "ptipoDocumento = 'C'" na chamada da SP "usp_Get_DWVendas";    
06/03/2025 WILLIAM
    - Inclusao do @empcod nos parametros de entrada da SP;
	- Udo da SP "usp_Get_DWVendas" e usp_Get_DWDevolucaoVendas, para obter as informacoes de vendas e devolucao de vendas, respectivamente;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
====================================================================================================================================================================================
*/
ALTER PROCEDURE [dbo].[usp_RS_ResumoVendasGZ]
	@empcod smallint,
	@datade date = null,
	@dataate date = null
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	DECLARE	@codigoEmpresa smallint, @data_De date, @data_Ate date;			

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod
	SET @data_De = (SELECT ISNULL(@datade, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@dataate, GETDATE()));

/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP

    -- Obter as vendas BRUTAS, abater os cancelamentos depois
	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,		
        @pDesconsiderarCancelados = 'N',    -- Lista as vendas que foram canceladas, para serapar o valor no final 
        @ptipoDocumento = 'C'	            -- Somente vendas feitas com cupom fiscal

	IF OBJECT_ID('tempdb..#VENDAS_CUPOM') IS NOT NULL
	    DROP TABLE #VENDAS_CUPOM;

    SELECT
        ISNULL(SUM(valorTotal), 0) AS total_bruto,
        ISNULL(SUM(custoTotal), 0) AS total_custo, 
        ISNULL(COUNT(DISTINCT numeroDocumento), 0) AS q_cupons_total
    INTO #VENDAS_CUPOM FROM ##DWVendas
    
    WHERE        
        documentoReferenciado = ''

--    SELECT * FROM #VENDAS_CUPOM;

    DROP TABLE ##DWVendas;

    -- Obter somente as vendas canceladados, para abater do total bruto obtido acima
	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,		
		@pSomenteCancelados = 'S' ,
        @ptipoDocumento = 'C'	            -- Somente vendas feitas com cupom fiscal        

	IF OBJECT_ID('tempdb..#VENDASCAN_CUPOM') IS NOT NULL
	    DROP TABLE #VENDASCAN_CUPOM;

    SELECT
        ISNULL(SUM(valorTotal), 0) AS cancelamento,
        ISNULL(SUM(custoTotal), 0) AS custo_cancelamento, 
        ISNULL(COUNT(DISTINCT numeroDocumento), 0) AS q_cupons_cancelados
    INTO #VENDASCAN_CUPOM FROM ##DWVendas
    
    WHERE
        documentoReferenciado = ''

    --SELECT * FROM #VENDASCAN_CUPOM;
    DROP TABLE ##DWVendas;

/***********************************************************************************************************************************************************************************
	Obter as devolucoes de venda da tabela DWDevolucaoVenda
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as devolucoes do grupo, loja e corporativo
	
	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate

	IF OBJECT_ID('tempdb..#DEVOLUCAO_CUPOM') IS NOT NULL
	    DROP TABLE #DEVOLUCAO_CUPOM;

    SELECT
        ISNULL(SUM(valorTotal), 0) AS total_devolvido,
        ISNULL(SUM(custoTotal), 0) AS custo_devolucao, 
        ISNULL(COUNT(DISTINCT numeroDocumento), 0) AS q_devolucoes
    INTO #DEVOLUCAO_CUPOM FROM ##DWDevolucaoVendas
    
    WHERE
        tipoEntrada = 'CUP'

--    SELECT * FROM #DEVOLUCAO_CUPOM;
    DROP TABLE ##DWDevolucaoVendas;
    
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utilizaremos CTE para contabilizar as vendas, cancelamento e devolucoes

    ;WITH
        resumovendas AS(
            SELECT
                total_bruto,
                total_custo,
                q_cupons_total,
                cancelamento,
                custo_cancelamento,
                q_cupons_cancelados,
                total_devolvido,
                custo_devolucao,
                q_devolucoes,

                ISNULL(q_cupons_total, 0) - ISNULL(q_cupons_cancelados, 0) - ISNULL(q_devolucoes, 0) AS 'qtde_cupons',
                ISNULL(total_bruto, 0) - ISNULL(cancelamento, 0) - ISNULL(total_devolvido, 0) AS 'total_liquido',
                ISNULL(total_custo, 0) - ISNULL(custo_cancelamento, 0) - ISNULL(custo_devolucao, 0) AS 'custo_liquido'
            FROM #VENDAS_CUPOM, #VENDASCAN_CUPOM, #DEVOLUCAO_CUPOM
        ),

        -- Faz um refinamento para calcular as porcentagens
        resumovendasfinal AS(
            SELECT
                *,
				ROUND(IIF(total_bruto = 0, 0, (1 - total_custo / total_bruto) * 100), 2) AS 'margem_lucro_bruto',
                ROUND(IIF(total_liquido = 0, 0, (1 - custo_liquido / total_liquido) * 100), 2) AS 'margem_lucro_liquido',
                ROUND(IIF(total_bruto = 0, 0, cancelamento / total_bruto * 100), 2) AS 'porc_cancelamento',
                ROUND(IIF(total_bruto = 0, 0, total_devolvido / total_bruto * 100), 2) AS 'porc_devolucao'
            FROM resumovendas
        )
        -- Tabela final
        SELECT
            *
        FROM resumovendasfinal        
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END