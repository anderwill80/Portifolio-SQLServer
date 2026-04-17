/*
====================================================================================================================================================================================
WREL074 - Venda de Produtos do Corportativo
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
10/04/2025 WILLIAM	
    - Uso do parametro "ptipoDocumento = 'N'" na chamada da SP "usp_Get_DWVendas", para obter apenas registros de notas;
25/03/2025 WILLIAM
	- Uso das SPs "usp_Get_DWVendas" e "usp_Get_DWDevolucaoVendas", para obter as informacoes vendas e devolucao;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
27/12/2024 WILLIAM
	- Leitura do parametro 1136, para saber se empresa tem frente de loja, se tiver, o valor ser� o CNPJ da empresa, que sera comparada com o CNPJ da TBS023;
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Alteracao nos parametros da chamada da SP "usp_ClientesGrupo", passando o codigo da empresa @codigoEmpresa;
====================================================================================================================================================================================
*/
--ALTER PROCEDURE [dbo].[usp_RS_VendaProdutoCorportativo_DEBUG] 
create PROCEDURE [dbo].[usp_RS_VendaProdutoCorportativo] 
	@empcod smallint,
	@dataDe date, 
	@dataAte date, 
	@codigoProduto varchar(15) = '' , 
	@descricaoProduto varchar(60) = '',
	@codigoMarca int = 0, 
	@nomeMarca varchar(60) = '',	
	@pGrupoBMPT char(1) = 'S'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	DECLARE	@codigoEmpresa smallint, @data_De date, @data_Ate date, @PROCOD varchar(15), @PRODES varchar(60), @MARCOD int, @MARNOM varchar(30), @GrupoBMPT char(1),
			@contabiliza varchar(10);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod
	SET @DATA_DE = (SELECT ISNULL(@dataDe, '17530101'));
	SET @DATA_ATE = (SELECT ISNULL(@dataAte, GETDATE() - 1));
	SET @MARCOD = @codigoMarca;
	SET @MARNOM = UPPER(LTRIM(RTRIM(@nomeMarca)));
	SET	@PROCOD = LTRIM(RTRIM(@codigoProduto));
	SET @PRODES = UPPER(LTRIM(RTRIM(@descricaoProduto)));
	SET @GrupoBMPT = UPPER(@pGrupoBMPT);

-- Atribuicoes internas
	-- Verifica se usuario escolheu para contabilizar vendas das empresas do grupo ou nao, para passar para a SP: C:corporativo;L-loja;G-grupo BMPT
	SET @contabiliza = IIF(@GrupoBMPT = 'N', 'C', 'C,G');

/***********************************************************************************************************************************************************************************
	Obter as vendas da tabela DWVendas
***********************************************************************************************************************************************************************************/	
	-- Com as vendas obtidas via tabela temporaria ##DWVendas criada pela SP, conseguimos separar as vendas do grupo, loja e corporativo

	EXEC usp_Get_DWVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoMarca = @MARCOD,
		@pnomeMarca =  @MARNOM,
		@pcontabiliza = @contabiliza,
		@ptipoDocumento = 'N';			-- Busca somente registros de notas fiscais, corporativo ou loja

/***********************************************************************************************************************************************************************************
	Obter as devolucoes de venda da tabela DWDevolucaoVenda
***********************************************************************************************************************************************************************************/	
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as devolucoes do grupo, loja e corporativo
	
	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoMarca = @MARCOD,
		@pnomeMarca =  @MARNOM,
		@pcontabiliza = @contabiliza	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para contabilizar as vendas e devolucoes para cada grupo de vendas(Loja, corporativo e grupo BMPT)
	
	;WITH 
		-- Primeiro CTE agrupa dos registros por produto
		distinct_pro AS (
			SELECT 
				DISTINCT codigoProduto,
				descricaoProduto AS descricao,
				CASE WHEN LEN(codigoMarca) = 4 
					THEN RTRIM(codigoMarca) + ' - ' + RTRIM(nomeMarca) 
					ELSE RIGHT(('0000' + LTRIM(STR(codigoMarca))), 4) + ' - ' + RTRIM(nomeMarca)
				END AS codigoNomeMarca,
				RTRIM(nomeGrupo) + ' (' + LTRIM(STR(codigoGrupo,3)) + ')' AS nomeGrupo,
				RTRIM(nomeSubgrupo) + ' (' + LTRIM(STR(codigoSubgrupo,3)) + ')' AS nomeSubgrupo				
			FROM ##DWVendas
		),

		produtos AS (
			SELECT 
				*,
				PROUM1 AS menorUnidade
			FROM distinct_pro
			JOIN TBS010 ON codigoProduto = PROCOD
		),		
		-- Vendas contabilizadas para o corporativo
		vendas_corp AS (
			SELECT  
				codigoProduto,
				ISNULL(SUM(quantidade), 0) AS quantidadeCorporativo,
				ISNULL(SUM(valorTotal), 0) AS valorLiquidoCorporativo
			FROM ##DWVendas
			
			WHERE 
				contabiliza = 'C'
			-- 	AND documentoReferenciado = ''
			GROUP BY 
				codigoProduto
		),
		-- Devolucoes contabilizadas para o corporativo
		devol_corp AS (
			SELECT  
				codigoProduto,
				ISNULL(SUM(quantidade), 0) AS quantidadeDevolucaoCorporativo,
				ISNULL(SUM(valorTotal), 0) AS valorDevolucaoCorporativo
			FROM ##DWDevolucaoVendas			

			WHERE 
				contabiliza = 'C'
			GROUP BY 
				codigoProduto
		),
		-- Vendas contabilizadas para o grupo BMPT
		vendas_grupo AS (
			SELECT  
				codigoProduto,
				ISNULL(SUM(quantidade), 0) AS quantidadeGrupo,
				ISNULL(SUM(valorTotal), 0) AS valorLiquidoGrupo
			FROM ##DWVendas
			
			WHERE 
				contabiliza = 'G'
				-- AND documentoReferenciado = ''
			GROUP BY 
				codigoProduto
		),
		-- Devolucoes contabilizadas para o grupo BMPT
		devol_grupo AS (
			SELECT  
				codigoProduto,
				ISNULL(SUM(quantidade), 0) as quantidadeDevolucaoGrupo,
				ISNULL(SUM(valorTotal), 0) AS valorDevolucaoGrupo
			FROM ##DWDevolucaoVendas			

			WHERE 
				contabiliza = 'G'
			GROUP BY 
				codigoProduto
		)	
		-- Tabela final
		SELECT  
			p.codigoProduto AS PROCOD,
			descricao AS PRODES,
			codigoNomeMarca AS MARCA,
			nomeGrupo AS grupo,
			nomeSubgrupo AS subgrupo,
			menorUnidade AS PROUM1,

			IIF(ISNULL(quantidadeCorporativo, 0) = 0, 0, round(valorLiquidoCorporativo / quantidadeCorporativo, 2)) AS NFSPREMED,		
			ISNULL(quantidadeCorporativo, 0) AS NFSQTDVEN,
			ISNULL(valorLiquidoCorporativo, 0) AS NFSTOTITEST,
			IIF(ISNULL(quantidadeDevolucaoCorporativo, 0) = 0, 0, round(valorDevolucaoCorporativo / quantidadeDevolucaoCorporativo, 2)) AS NFEPREMEDCOR,
			ISNULL(quantidadeDevolucaoCorporativo, 0) AS NFEQTDDEVCOR,					
			ISNULL(valorDevolucaoCorporativo, 0) AS NFETOTOPEITECOR,
			
			IIF(ISNULL(quantidadeGrupo, 0) = 0, 0, round(valorLiquidoGrupo / quantidadeGrupo, 2)) AS NFSPREMEDGRU,		
			ISNULL(quantidadeGrupo, 0) AS NFSQTDVENGRU,
			ISNULL(valorLiquidoGrupo, 0) AS NFSTOTITESTGRU,

			IIF(ISNULL(quantidadeDevolucaoGrupo, 0) = 0, 0, round(valorDevolucaoGrupo / quantidadeDevolucaoGrupo, 2)) AS NFEPREMEDGRU,
			ISNULL(quantidadeDevolucaoGrupo, 0) AS NFEQTDDEVGRU,					
			ISNULL(valorDevolucaoGrupo, 0) AS NFETOTOPEITEGRU
			
			-- ISNULL(quantidadeLoja, 0) + ISNULL(quantidadeCorporativo, 0) + ISNULL(quantidadeGrupo, 0) AS quantidadeTotal,
			-- ISNULL(valorLiquidoLoja, 0) + ISNULL(valorLiquidoCorporativo, 0) + ISNULL(valorLiquidoGrupo, 0) AS valorLiquidoTotal			 
		FROM produtos AS p
			LEFT JOIN vendas_corp AS vc ON p.codigoProduto = vc.codigoProduto
			LEFT JOIN devol_corp AS dc ON p.codigoProduto = dc.codigoProduto
			LEFT JOIN vendas_grupo AS vg ON p.codigoProduto = vg.codigoProduto
			LEFT JOIN devol_grupo AS dg ON p.codigoProduto = dg.codigoProduto

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga tabela temporia sem uso a partir desse ponto do codigo

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END 