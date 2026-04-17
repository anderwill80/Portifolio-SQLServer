/*
====================================================================================================================================================================================
Resumo de vendas Integros | SubRelatorio - chamado por dentro do Faturamento NFS X CUPOM
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
09/04/2025 WILLIAM
	- Inclusao de comando para apagar as tabelas temporarias globais ##DWVendas e ##DWDevolucaoVendas, ao final do script;
    - Uso do parametro "ptipoDocumento = 'N'" na chamada da SP "usp_Get_DWVendas", para obter apenas registros de notas do corporativo, via pedido de vendas;   
06/03/2025 WILLIAM
    - Inclusao do @empcod nos parametros de entrada da SP;
	- Udo da SP "usp_Get_DWVendas" e usp_Get_DWDevolucaoVendas, para obter as informacoes de vendas e devolucao de vendas, respectivamente;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
************************************************************************************************************************************************************************************
*/
ALTER PROCEDURE [dbo].[usp_RS_ResumoVendasIntegros]
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
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

    -- Obter as vendas BRUTAS, abater os cancelamentos depois
	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcontabiliza = 'C,L',
        @pDesconsiderarCancelados = 'N', -- Lista as vendas que foram canceladas, para serapar o valor no final 
        @ptipoDocumento = 'N';

	IF OBJECT_ID('tempdb..#VENDAS_CORPORATIVO') IS NOT NULL
	    DROP TABLE #VENDAS_CORPORATIVO;

    SELECT
        ISNULL(sum(valorTotal), 0) AS total_bruto,
        ISNULL(sum(custoTotal), 0) AS total_custo, 
        ISNULL(count(distinct numeroDocumento), 0) AS q_notas_total
    INTO #VENDAS_CORPORATIVO FROM ##DWVendas
    
    WHERE
        documentoReferenciado = ''

--    SELECT * FROM #VENDAS_CORPORATIVO;

    DROP TABLE ##DWVendas;

    -- Obter somente as vendas canceladados, para abater do total bruto obtido acima
	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcontabiliza = 'C,L',    
		@pSomenteCancelados = 'S',
        @ptipoDocumento = 'N';        

	IF OBJECT_ID('tempdb..#VENDASCAN_CORPORATIVO') IS NOT NULL
	    DROP TABLE #VENDASCAN_CORPORATIVO;

    SELECT
        ISNULL(sum(valorTotal), 0) AS cancelamento,
        ISNULL(sum(custoTotal), 0) AS custo_cancelamento, 
        ISNULL(count(distinct numeroDocumento), 0) AS q_notas_canceladas
    INTO #VENDASCAN_CORPORATIVO FROM ##DWVendas
    
    WHERE
        documentoReferenciado = ''

--SELECT * FROM #VENDASCAN_CORPORATIVO;
/***********************************************************************************************************************************************************************************
	Obter as devolucoes de venda da tabela DWDevolucaoVenda
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as devolucoes do grupo, loja e corporativo
	
	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,        
        @pcontabiliza = 'C,L'

	IF OBJECT_ID('tempdb..#DEVOLUCAO_CORPORATIVO') IS NOT NULL
	    DROP TABLE #DEVOLUCAO_CORPORATIVO;

    SELECT
        ISNULL(sum(valorTotal), 0) AS total_devolvido,
        ISNULL(sum(custoTotal), 0) AS custo_devolucao, 
        ISNULL(count(distinct numeroDocumento), 0) AS q_devolucoes
    INTO #DEVOLUCAO_CORPORATIVO FROM ##DWDevolucaoVendas
    
    WHERE
        tipoEntrada <> 'CUP'

--    SELECT * FROM #DEVOLUCAO_CORPORATIVO;    
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- Utilizaremos CTE para contabilizar as vendas, cancelamento e devolucoes

    ;WITH
        resumovendas AS(
            SELECT
                total_bruto,
                total_custo,
                q_notas_total,
                cancelamento,
                custo_cancelamento,
                q_notas_canceladas,
                total_devolvido,
                custo_devolucao,
                q_devolucoes,

                ISNULL(q_notas_total, 0) - ISNULL(q_notas_canceladas, 0) - ISNULL(q_devolucoes, 0) AS 'qtde_notas',
                ISNULL(total_bruto, 0) - ISNULL(cancelamento, 0) - ISNULL(total_devolvido, 0) AS 'total_liquido',
                ISNULL(total_custo, 0) - ISNULL(custo_cancelamento, 0) - ISNULL(custo_devolucao, 0) AS 'custo_liquido'
            FROM #VENDAS_CORPORATIVO, #VENDASCAN_CORPORATIVO, #DEVOLUCAO_CORPORATIVO
        ),

        -- Faz um refinamento para calcular as porcentagens
        resumovendasfinal AS(
            SELECT
                *,
                IIF(total_bruto = 0, 0, (1- total_custo / total_bruto) * 100) AS 'margem_lucro_bruto',
                IIF(total_liquido = 0, 0, (1- custo_liquido / total_liquido) * 100) as 'margem_lucro_liquido',
                IIF(total_bruto = 0, 0, cancelamento / total_bruto * 100) as 'porc_cancelamento',
                IIF(total_bruto = 0, 0, total_devolvido / total_bruto * 100) as 'porc_devolucao'
            FROM resumovendas
        )
        -- Tabela final
        SELECT
                total_bruto,
                total_custo,
                q_notas_total,
                ISNULL(cancelamento, 0) AS cancelamento,
                ISNULL(custo_cancelamento, 0) AS custo_cancelamento,
                ISNULL(q_notas_canceladas, 0) AS q_notas_canceladas,
                ISNULL(total_devolvido, 0) AS total_devolvido,
                ISNULL(custo_devolucao, 0) AS custo_devolucao,
                ISNULL(q_devolucoes, 0) AS q_devolucoes,
                qtde_notas,
                total_liquido,
                custo_liquido,
                margem_lucro_bruto,
                margem_lucro_liquido,
                porc_cancelamento,
                porc_devolucao
        FROM resumovendasfinal        
/**/
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga tabela temporia sem uso a partir desse ponto do codigo

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------				
END