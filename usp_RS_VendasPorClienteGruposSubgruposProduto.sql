/*
====================================================================================================================================================================================
WREL078 - Vendas por cliente - grupos e subgrupos de produtos
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
24/03/2026 WILLIAM
	- Inclusao do atributo unidade1 no agrupamento das vendas, para nao precisar dar JOIN na TBS010 para cada produto, existe uma rotina que esta sincronizando os dados dos produtos
	com a DWVendas, dessa forma nao teremos unidade diferente na TBS010 e DWVendas;
09/02/2026 WILLIAM
	- Conversao do parametro de entrada de varchar para int: @codigoCliente;
27/03/2025 WILLIAM
	- Uso das SPs "usp_Get_DWVendas" e "usp_Get_DWDevolucaoVendas", para obter as informacoes vendas e devolucao;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Correcao, alterando o tipo do parametro @codigoCliente de int para varchar(100), pois nao estava filtrando por cliente na SP "usp_Get_DWVendas";	
	- Retirada de codigo sem uso;	
20/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;		
====================================================================================================================================================================================
*/
--ALTER PROCEDURE [dbo].[usp_RS_VendasPorClienteGruposSubgruposProduto_DEBUG]
ALTER PROCEDURE [dbo].[usp_RS_VendasPorClienteGruposSubgruposProduto]
	@empcod smallint,
	@dataDe date,
	@dataAte date,
	@codigoCliente int = 0,
	@nomeCliente varchar(60) = '',	
	@codigoProduto varchar(15) = '',
	@descricaoProduto varchar(60) = '',
	@codigoGrupo varchar(5000) = '',
	@codigoSubGrupo varchar(5000) = '',
	@codigoMarca int = 0,
	@nomeMarca varchar(60) = '',
	@pGrupoBMPT char(1) = 'S'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @data_De datetime, @data_Ate datetime, @CLICOD int, @CLINOM varchar(60), @MARCOD int, @MARNOM varchar(60), @PROCOD varchar(15), @PRODES varchar(60), 
			@GRUPOS varchar(100), @SUBGRUPOS varchar(5000), @GrupoBMPT char(1),
			@contabiliza varchar(10);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @data_Ate = (SELECT ISNULL(@dataAte, GETDATE() - 1));
	SET @CLICOD = @codigoCliente;
	SET @CLINOM = @nomeCliente;
	SET @MARCOD = @codigoMarca;
	SET @MARNOM = @nomeMarca;
	SET @PROCOD = @codigoProduto;
	SET @PRODES = @descricaoProduto;
	SET @GRUPOS = @codigoGrupo;
	SET @SUBGRUPOS = @codigoSubGrupo;
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
		@pcodigoCliente = @CLICOD,
		@pnomeCliente = @CLINOM,			
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoGrupoProduto = @GRUPOS,
		@pcodigoSubGrupoProduto = @SUBGRUPOS,		
		@pcodigoMarca = @MARCOD,
		@pnomeMarca =  @MARNOM,
		@pcontabiliza = @contabiliza

--select * from ##DWVendas;
/***********************************************************************************************************************************************************************************
	Obter as devolucoes de venda da tabela DWDevolucaoVenda
***********************************************************************************************************************************************************************************/
	-- Com as devolucoes obtidas via tabela temporaria ##DWDevolucaoVendas criada pela SP, conseguimos separar as devolucoes do grupo, loja e corporativo
	
	EXEC usp_Get_DWDevolucaoVendas
		@empcod = @codigoEmpresa,
		@pdataDe = @data_De,
		@pdataAte = @data_Ate,
		@pcodigoCliente = @CLICOD,
		@pnomeCliente = @CLINOM,			
		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoGrupoProduto = @GRUPOS,
		@pcodigoSubGrupoProduto = @SUBGRUPOS,		
		@pcodigoMarca = @MARCOD,
		@pnomeMarca =  @MARNOM,
		@pcontabiliza = @contabiliza	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para contabilizar as vendas e devolucoes para cada grupo de vendas(Loja, corporativo e grupo BMPT)
	
	;WITH 
		-- Primeiro CTE agrupa dos registros por produto
		produtos AS (
			SELECT 
				codigoCliente,
				nomeCliente,			
				codigoProduto,
				descricaoProduto AS descricao,
				CASE WHEN LEN(codigoMarca) = 4 
					THEN RTRIM(codigoMarca) + ' - ' + RTRIM(nomeMarca) 
					ELSE RIGHT(('0000' + LTRIM(STR(codigoMarca))), 4) + ' - ' + RTRIM(nomeMarca)
				END AS codigoNomeMarca,
				RTRIM(nomeGrupo) + ' (' + LTRIM(STR(codigoGrupo,3)) + ')' AS nomeGrupo,
				RTRIM(nomeSubgrupo) + ' (' + LTRIM(STR(codigoSubgrupo,3)) + ')' AS nomeSubgrupo,
				unidade1
			FROM ##DWVendas

			WHERE 
				codigoCliente > 0 -- somente cliente com cadastro em nosso sistema				

			GROUP BY 
				codigoCliente,
				nomeCliente,
				codigoProduto,
				descricaoProduto,
				codigoMarca,
				nomeMarca,
				codigoGrupo,
				nomeGrupo,
				codigoSubgrupo,
				nomeSubgrupo,
				unidade1

		),	

		-- Vendas contabilizadas para a loja
		vendas_loja AS (
			SELECT  
				codigoCliente,
				nomeCliente,
				codigoProduto,
				ISNULL(SUM(quantidade), 0) AS quantidadeLoja,
				ISNULL(SUM(valorTotal), 0) AS valorLiquidoLoja
			FROM ##DWVendas

			WHERE 
				contabiliza = 'L' 
				AND documentoReferenciado = ''

			GROUP BY 
				codigoCliente,
				nomeCliente,			
				codigoProduto
			),
		-- Devolucoes contabilizadas para a loja
		devol_loja AS (
			SELECT  
				codigoCliente,
				nomeCliente,			
				codigoProduto,
				ISNULL(SUM(quantidade), 0) AS quantidadeDevolucaoLoja,
				ISNULL(SUM(valorTotal), 0) AS valorDevolucaoLoja
			FROM ##DWDevolucaoVendas			

			WHERE 
				contabiliza = 'L' 

			GROUP BY 
				codigoCliente,
				nomeCliente,			
				codigoProduto
		),
		-- Vendas contabilizadas para o corporativo
		vendas_corp AS (
			SELECT  
				codigoCliente,
				nomeCliente,			
				codigoProduto,
				ISNULL(SUM(quantidade), 0) AS quantidadeCorporativo,
				ISNULL(SUM(valorTotal), 0) AS valorLiquidoCorporativo
			FROM ##DWVendas
			
			WHERE 
				contabiliza = 'C'
				AND documentoReferenciado = ''
			GROUP BY 
				codigoCliente,
				nomeCliente,			
				codigoProduto
		),
		-- Devolucoes contabilizadas para o corporativo
		devol_corp AS (
			SELECT  
				codigoCliente,
				nomeCliente,			
				codigoProduto,
				ISNULL(SUM(quantidade), 0) AS quantidadeDevolucaoCorporativo,
				ISNULL(SUM(valorTotal), 0) AS valorDevolucaoCorporativo
			FROM ##DWDevolucaoVendas			

			WHERE 
				contabiliza = 'C'
			GROUP BY 
				codigoCliente,
				nomeCliente,			
				codigoProduto
		),
		-- Vendas contabilizadas para o grupo BMPT
		vendas_grupo AS (
			SELECT  
				codigoCliente,
				nomeCliente,			
				codigoProduto,
				ISNULL(SUM(quantidade), 0) AS quantidadeGrupo,
				ISNULL(SUM(valorTotal), 0) AS valorLiquidoGrupo
			FROM ##DWVendas
			
			WHERE 
				contabiliza = 'G'
				AND documentoReferenciado = ''
			GROUP BY 
				codigoCliente,
				nomeCliente,			
				codigoProduto
		),
		-- Devolucoes contabilizadas para o grupo BMPT
		devol_grupo AS (
			SELECT  
				codigoCliente,
				nomeCliente,			
				codigoProduto,
				ISNULL(SUM(quantidade), 0) as quantidadeDevolucaoGrupo,
				ISNULL(SUM(valorTotal), 0) AS valorDevolucaoGrupo
			FROM ##DWDevolucaoVendas			

			WHERE 
				contabiliza = 'G'				
			GROUP BY 
				codigoCliente,
				nomeCliente,			
				codigoProduto
		)	
		-- Tabela final
		SELECT  
			p.codigoCliente AS NFSCLICOD,
			p.nomeCliente AS NFSCLINOM,
			p.codigoProduto AS PROCOD,
			descricao AS PRODES,
			codigoNomeMarca AS MARCA,
			nomeGrupo AS grupo,
			nomeSubgrupo AS subgrupo,
			unidade1 AS PROUM1,

			IIF(ISNULL(quantidadeLoja, 0) = 0, 0, round(valorLiquidoLoja / quantidadeLoja, 2)) AS LOJPREMED,		
			ISNULL(quantidadeLoja, 0) AS LOJQTDVEN,
			ISNULL(valorLiquidoLoja, 0) AS LOJVALVEN,
			IIF(ISNULL(quantidadeDevolucaoLoja, 0) = 0, 0, round(valorDevolucaoLoja / quantidadeDevolucaoLoja, 2)) AS NFEPREMEDLOJ,
			ISNULL(quantidadeDevolucaoLoja, 0) AS NFEQTDDEVLOJ,					
			ISNULL(valorDevolucaoLoja, 0) AS NFETOTOPEITELOJ,

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
			LEFT JOIN vendas_loja AS vl ON p.codigoCliente = vl.codigoCliente AND p.codigoProduto = vl.codigoProduto
			LEFT JOIN devol_loja AS dl ON p.codigoCliente  = dl.codigoCliente AND p.codigoProduto = dl.codigoProduto
			LEFT JOIN vendas_corp AS vc ON p.codigoCliente = vc.codigoCliente AND p.codigoProduto = vc.codigoProduto
			LEFT JOIN devol_corp AS dc ON p.codigoCliente = dc.codigoCliente AND p.codigoProduto = dc.codigoProduto
			LEFT JOIN vendas_grupo AS vg ON p.codigoCliente = vg.codigoCliente AND p.codigoProduto = vg.codigoProduto
			LEFT JOIN devol_grupo AS dg ON p.codigoCliente  = dg.codigoCliente AND p.codigoProduto = dg.codigoProduto		

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga as temporarias globais

	DROP TABLE ##DWVendas;
	DROP TABLE ##DWDevolucaoVendas;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END