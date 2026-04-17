/*
====================================================================================================================================================================================
WREL082 - Vendas por Vendedores 
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
10/04/2025 WILLIAM
	- Correcao, alterando o tipo do parametro @codigoVendedor varchar(500), pois nao estava filtrando por vencedor na SP "usp_Get_DWVendas";
    - Uso do parametro "ptipoDocumento = 'N'" na chamada da SP "usp_Get_DWVendas", para obter apenas registros de notas;
13/03/2025 WILLIAM
	- Uso das SPs "usp_Get_DWVendas" e "usp_Get_DWDevolucaoVendas", para obter as informacoes vendas e devolucao;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
06/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Troca da SP "sp_VendasVendedores" pela "usp_RS_VendasVendedores";	
====================================================================================================================================================================================
*/
--ALTER PROCEDURE [dbo].[usp_RS_VendasPorVendedores_DEBUG]
ALTER PROCEDURE [dbo].[usp_RS_VendasPorVendedores]
	@empcod smallint,
	@dataDe date,
	@dataAte date,
	@codigoVendedor varchar(500) = '',
	@nomeVendedor varchar(60) = '',
	@pGrupoBMPT char(1) = 'S'
AS 
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @data_De datetime, @data_Ate datetime, @VENCOD varchar(500), @VENNOM varchar(60), @GrupoBMPT char(1),
			@contabiliza varchar(10);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));
	SET @VENCOD = @codigoVendedor;
	SET @VENNOM = @nomeVendedor;
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
		@pnomeVendedor = @VENNOM,
		@pcontabiliza = @contabiliza,
		@ptipoDocumento = 'N';			-- Somente vendas feitas via notas fiscais, loja ou corporativo

/***********************************************************************************************************************************************************************************
	Obter as devolucoes de venda da tabela DWDevolucaoVenda
***********************************************************************************************************************************************************************************/
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as devolucoes do grupo, loja e corporativo
	
	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoVendedor = @VENCOD,
		@pnomeVendedor = @VENNOM,
		@pcontabiliza = @contabiliza			

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para contabilizar as vendas e devolucoes para cada grupo de vendas(Loja, corporativo e grupo BMPT)
	
	;WITH 
		datas AS (
			SELECT @data_De AS Data

			UNION ALL
			SELECT
				DATEADD(MONTH, 1, Data)
			FROM datas

			WHERE 
				CONVERT(CHAR(7), Data, 102) < CONVERT(CHAR(7), @Data_Ate, 102)
		),					
		datas_agrupadas AS (
			SELECT
				SUBSTRING(CONVERT(CHAR (10), Data, 103), 4, 7) AS MESANO, 
				CONVERT(CHAR(7), Data, 102) AS DATA 
			FROM datas

			GROUP BY
				CONVERT(CHAR(7), Data,102), 
				SUBSTRING(CONVERT(CHAR (10), Data, 103), 4, 7)
		),			
		-- Agrupa dos registros por cliente
		clientes_distinct AS (
			SELECT 
				DISTINCT codigoCliente AS CLICOD,
				nomeCliente AS CLINOM,
				codigoVendedor AS VENCOD,
				nomeVendedor AS VENNOM
			FROM ##DWVendas	

			WHERE
				codigoVendedor > 0	-- Filtra apenas notas emitidas por vendedores		
		),				
		clientes_data AS (
			SELECT 
				C.*,
				D.*
			FROM clientes_distinct C, datas_agrupadas D
		),				
		-- Vendas via cupom fiscal
		vendas_loja AS (
			SELECT  
				SUBSTRING(CONVERT(CHAR (10), data, 103), 4, 7) AS MESANO,
				CONVERT(CHAR(7), data, 102) AS DATA,
				codigoVendedor,
				nomeVendedor,
				codigoCliente,
				nomeCliente,
				ISNULL(SUM(valorTotal), 0) AS valorLoja
			FROM ##DWVendas

			WHERE 				
				documentoReferenciado <> '' -- todo nota emitida via cupom fiscal, armazena a chave do cupom nesse campo
				AND contabiliza <> 'G'

			GROUP BY 
				codigoVendedor,
				nomeVendedor,
				codigoCliente,
				nomeCliente, 
				SUBSTRING(CONVERT(CHAR (10), data, 103), 4, 7), 
				CONVERT(CHAR(7), data, 102)
		),
		-- Vendas via pedido de vendas
		vendas_corp AS (
			SELECT  
				SUBSTRING(CONVERT(CHAR (10), data, 103), 4, 7) AS MESANO,
				CONVERT(CHAR(7), data, 102) AS DATA,
				codigoVendedor,
				nomeVendedor,
				codigoCliente,
				nomeCliente,
				ISNULL(SUM(valorTotal), 0) AS valorCorp
			FROM ##DWVendas

			WHERE 												
				documentoReferenciado = '' -- todo nota emitida via pedido de vendas, nao tem documento referenciado
				AND contabiliza <> 'G'

			GROUP BY 
				codigoVendedor,
				nomeVendedor,
				codigoCliente,
				nomeCliente, 
				SUBSTRING(CONVERT(CHAR (10), data, 103), 4, 7), 
				CONVERT(CHAR(7), data, 102)
		),
		-- Vendas via pedido de vendas para o grupo
		vendas_grupo AS (
			SELECT  
				SUBSTRING(CONVERT(CHAR (10), data, 103), 4, 7) AS MESANO,
				CONVERT(CHAR(7), data, 102) AS DATA,
				codigoVendedor,
				nomeVendedor,
				codigoCliente,
				nomeCliente,
				ISNULL(SUM(valorTotal), 0) AS valorGrupo
			FROM ##DWVendas

			WHERE 								
				contabiliza = 'G'

			GROUP BY 
				codigoVendedor,
				nomeVendedor,
				codigoCliente,
				nomeCliente, 
				SUBSTRING(CONVERT(CHAR (10), data, 103), 4, 7), 
				CONVERT(CHAR(7), data, 102)
		),
		-- Devolucoes por cliente
		devolucoes AS (
			SELECT  
				SUBSTRING(CONVERT(CHAR (10), data, 103), 4, 7) AS MESANO,
				CONVERT(CHAR(7), data, 102) AS DATA,
				codigoVendedor,
				nomeVendedor,
				codigoCliente,
				nomeCliente,
				ISNULL(SUM(valorTotal), 0) AS valorDev
			FROM ##DWDevolucaoVendas

			GROUP BY 
				codigoVendedor,
				nomeVendedor,
				codigoCliente,
				nomeCliente, 
				SUBSTRING(CONVERT(CHAR (10), data, 103), 4, 7), 
				CONVERT(CHAR(7), data, 102)
		)			
		-- Tabela final
		SELECT  
			c.MESANO AS DATA,
			c.DATA AS DATA2,		
			VENCOD,
			VENNOM,
			CLICOD AS NFSCLICOD,
			CLINOM AS NFSCLINOM,			
			ISNULL(valorLoja, 0) AS VALITELOJA,
			ISNULL(valorCorp, 0) AS VALITENFE,					
			ISNULL(valorGrupo, 0) AS VALITECOM,						
			ISNULL(valorDev, 0) AS DEVOLUCAO
		FROM clientes_data AS c
			LEFT JOIN vendas_loja AS vl ON CLICOD = vl.codigoCliente AND c.DATA = vl.DATA
			LEFT JOIN vendas_corp AS vc ON CLICOD = vc.codigoCliente AND c.DATA = vc.DATA
			LEFT JOIN vendas_grupo AS vg ON CLICOD = vg.codigoCliente AND c.DATA = vg.DATA
			LEFT JOIN devolucoes AS dv ON CLICOD = dv.codigoCliente AND c.DATA = dv.DATA
		ORDER BY
			c.CLICOD, c.VENCOD, c.DATA

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga tabela temporia sem uso a partir desse ponto do codigo

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END
