/*
====================================================================================================================================================================================
WREL076 - Vendas Integros x GZ por agrupamento
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
24/03/2026 WILLIAM
	- Alteracao para agrupar as informacoes dos produtos como descricao, unidade, grupo, subgrupo e marca, e nao mais buscar na TBS010, pois agora e garantido que nao havera o mesmo
	produto com descrica, marca, grupo ou subgrupo diferentes, tem um rotina que sincroniza os dados todos os dias;
03/03/2026 WILLIAM
	- Unificacao do procedimento que sera usado tanto no relatorio WREL076(por agrupamento), quanto no WREL077(por item), trazem o mesmo resultado, a diferenca e no layout;
	- Alteracao do nome dos atributos na tabela final, para ficar iguais nos 2 relatorios;
08/12/2025 WILLIAM
	- Correcao ao agrupar os produtos vendidos da DWVendas, por causa da descricao diferente do produto, estava "duplicando" vendas;
	- Correcao ao agrupar os produtos, unificando os produtos que foram vendidos com os que foram devolvidos, estava dando diferencao quando havia devolucao de produto que 
nao tinha venda;
11/03/2025 WILLIAM
	- Uso das SPs "usp_Get_DWVendas" e "usp_Get_DWDevolucaoVendas", para obter as informacoes vendas e devolucao;
	- Utilizacao da tecnica CTE, para agrupar as vendas e devolucoes conforme para a loja, corporativo e grupo BMPT;
	- Retirada de codigo sem uso;
24/02/2025 WILLIAM
	- Retirada da chamada a SP "usp_movcaixa", devido a unificacao dos dados entre o BD da GZ e do Integros, na tabela "movcaixagz";
19/12/2024 - WILLIAM
- Leitura do parametro 1136, para saber se empresa tem frente de loja, se tiver, o valor sera o CNPJ da empresa, que sera comparada com o CNPJ da TBS023;
- Inclusao do @empcod nos parametros de entrada da SP;
- Alteracao nos parametros da chamada da SP "usp_ClientesGrupo", passando o codigo da empresa @codigoEmpresa;
====================================================================================================================================================================================
*/
--CREATE PROCEDURE [dbo].[usp_RS_VendasIntegrosxGZ_DEBUG]
ALTER PROCEDURE [dbo].[usp_RS_VendasIntegrosxGZ]
	@empcod smallint,
	@dataDe date = null,
	@dataAte date = null,
	@codigoMarca int = 0,
	@nomeMarca varchar(30) = '',
	@codigoProduto varchar(15) = '',
	@descricaoProduto varchar(60) = '',
	@codigoGrupo varchar(100) = '',
	@codigoSubGrupo varchar(5000) = '',
	@pGrupoBMPT char(1) = 'S'
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE	@codigoEmpresa smallint, @data_De date, @data_Ate date, @MARCOD int, @MARNOM varchar(30), @PROCOD varchar(15), @PRODES varchar(60),
			@GRUPOS varchar(100), @SUBGRUPOS varchar(5000), @GrupoBMPT char(1),
			@contabiliza varchar(10);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Data_De = (SELECT ISNULL(@dataDe, '17530101'));
	SET @Data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));
	SET @MARCOD = @codigoMarca;
	SET @MARNOM = @nomeMarca;
	SET	@PROCOD = @codigoProduto;
	SET @PRODES = @descricaoProduto;
	SET @GRUPOS = @codigoGrupo;
	SET @SUBGRUPOS = @CodigoSubGrupo;
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
		@pdataDe = @DATA_DE,
		@pdataAte = @DATA_ATE,
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
		@pdataDe = @DATA_DE,
		@pdataAte = @DATA_ATE,
 		@pcodigoProduto = @PROCOD,
		@pdescricaoProduto = @PRODES,
		@pcodigoGrupoProduto = @GRUPOS,
		@pcodigoSubGrupoProduto = @SUBGRUPOS,
		@pcodigoMarca = @MARCOD,
		@pnomeMarca =  @MARNOM,
		@pcontabiliza = @contabiliza	

--SELECT sum(valorTotal) FROM ##DWDevolucaoVendas WHERE contabiliza = 'L';

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Utilizaremos CTE para contabilizar as vendas e devolucoes para cada grupo de vendas(Loja, corporativo e grupo BMPT)
	
	;WITH 
		-- Primeiro CTE agrupa dos registros por produto
		produtos_unicos_vendas AS (
		SELECT		
			codigoProduto, 
			descricaoProduto, 
			codigoGrupo, 
			nomeGrupo, 
			codigoSubgrupo, 
			nomeSubgrupo,
			codigoMarca,
			nomeMarca,
			unidade1
		FROM ##DWVendas
		
		GROUP BY 
			codigoProduto, 
			descricaoProduto, 
			codigoGrupo, 
			nomeGrupo, 
			codigoSubgrupo, 
			nomeSubgrupo,
			codigoMarca,
			nomeMarca,
			unidade1
		),		

		produtos_unicos_devolucao AS (
		SELECT		
			codigoProduto, 
			descricaoProduto, 
			codigoGrupo, 
			nomeGrupo, 
			codigoSubgrupo, 
			nomeSubgrupo,
			codigoMarca,
			nomeMarca,
			unidade1
		FROM ##DWDevolucaoVendas
		
		GROUP BY 
			codigoProduto, 
			descricaoProduto, 
			codigoGrupo, 
			nomeGrupo, 
			codigoSubgrupo, 
			nomeSubgrupo,
			codigoMarca,
			nomeMarca,
			unidade1
		),		

		produtos_unificados AS(
			SELECT 
				*		
			FROM produtos_unicos_vendas
			UNION
			SELECT 
				*		
			FROM produtos_unicos_devolucao			
		),
		 -- Formata campos dos produtos
		produtos AS (
			SELECT 
				codigoProduto,
				descricaoProduto AS descricao,
				unidade1 AS menorUnidade,
				CASE WHEN LEN(codigoMarca) = 4 
					THEN RTRIM(codigoMarca) + ' - ' + RTRIM(nomeMarca) 
					ELSE RIGHT(('0000' + LTRIM(STR(codigoMarca))), 4) + ' - ' + RTRIM(nomeMarca)
				END AS codigoNomeMarca,
				RTRIM(nomeGrupo) + ' (' + ISNULL(LTRIM(STR(codigoGrupo, 3)), 0) + ')' AS nomeGrupo,
				RTRIM(nomeSubgrupo) + ' (' + ISNULL(LTRIM(STR(codigoSubgrupo, 3)), 0) + ')' AS nomeSubgrupo
			FROM produtos_unificados
		),
		--select * from produtos;
		
		-- Vendas contabilizadas para a loja
		vendas_loja AS (
			SELECT  
				codigoProduto,
				ISNULL(SUM(quantidade), 0) AS quantidadeLoja,
				ISNULL(SUM(valorTotal), 0) AS valorLiquidoLoja
			FROM ##DWVendas

			WHERE 
				contabiliza = 'L' 
				AND documentoReferenciado = ''

			GROUP BY 
				codigoProduto
		),
			
		-- Devolucoes contabilizadas para a loja
		devol_loja AS (
			SELECT  
				codigoProduto,
				ISNULL(SUM(quantidade), 0) AS quantidadeDevolucaoLoja,
				ISNULL(SUM(valorTotal), 0) AS valorDevolucaoLoja
			FROM ##DWDevolucaoVendas			

			WHERE 
				contabiliza = 'L' 

			GROUP BY 
				codigoProduto
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
				AND documentoReferenciado = ''
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
				AND documentoReferenciado = ''
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
			p.codigoProduto,
			descricao,
			codigoNomeMarca,
			nomeGrupo,
			nomeSubgrupo,
			menorUnidade,

			IIF(ISNULL(quantidadeLoja, 0) = 0, 0, round(valorLiquidoLoja / quantidadeLoja, 2)) AS precoMedioLoja,		
			ISNULL(quantidadeLoja, 0) AS quantidadeLoja,
			ISNULL(valorLiquidoLoja, 0) AS valorLiquidoLoja,
			IIF(ISNULL(quantidadeDevolucaoLoja, 0) = 0, 0, round(valorDevolucaoLoja / quantidadeDevolucaoLoja, 2)) AS precoMedioDevolucaoLoja,
			ISNULL(quantidadeDevolucaoLoja, 0) AS quantidadeDevolucaoLoja,					
			ISNULL(valorDevolucaoLoja, 0) AS valorDevolucaoLoja,

			IIF(ISNULL(quantidadeCorporativo, 0) = 0, 0, round(valorLiquidoCorporativo / quantidadeCorporativo, 2)) AS precoMedioCorporativo,		
			ISNULL(quantidadeCorporativo, 0) AS quantidadeCorporativo,
			ISNULL(valorLiquidoCorporativo, 0) AS valorLiquidoCorporativo,
			IIF(ISNULL(quantidadeDevolucaoCorporativo, 0) = 0, 0, round(valorDevolucaoCorporativo / quantidadeDevolucaoCorporativo, 2)) AS precoMedioDevolucaoCorporativo,
			ISNULL(quantidadeDevolucaoCorporativo, 0) AS quantidadeDevolucaoCorporativo,					
			ISNULL(valorDevolucaoCorporativo, 0) AS valorDevolucaoCorporativo,
			
			IIF(ISNULL(quantidadeGrupo, 0) = 0, 0, round(valorLiquidoGrupo / quantidadeGrupo, 2)) AS precoMedioGrupo,		
			ISNULL(quantidadeGrupo, 0) AS quantidadeGrupo,
			ISNULL(valorLiquidoGrupo, 0) AS valorLiquidoGrupo,
			IIF(ISNULL(quantidadeDevolucaoGrupo, 0) = 0, 0, round(valorDevolucaoGrupo / quantidadeDevolucaoGrupo, 2)) AS precoMedioDevolucaoGrupo,
			ISNULL(quantidadeDevolucaoGrupo, 0) AS quantidadeDevolucaoGrupo,					
			ISNULL(valorDevolucaoGrupo, 0) AS valorDevolucaoGrupo,						
			
			ISNULL(quantidadeLoja, 0) + ISNULL(quantidadeCorporativo, 0) + ISNULL(quantidadeGrupo, 0) AS quantidadeTotal,
			ISNULL(valorLiquidoLoja, 0) + ISNULL(valorLiquidoCorporativo, 0) + ISNULL(valorLiquidoGrupo, 0) AS valorLiquidoTotal			 
		FROM produtos AS p
			LEFT JOIN vendas_loja AS vl ON p.codigoProduto = vl.codigoProduto
			LEFT JOIN devol_loja AS dl ON p.codigoProduto = dl.codigoProduto
			LEFT JOIN vendas_corp AS vc ON p.codigoProduto = vc.codigoProduto
			LEFT JOIN devol_corp AS dc ON p.codigoProduto = dc.codigoProduto
			LEFT JOIN vendas_grupo AS vg ON p.codigoProduto = vg.codigoProduto
			LEFT JOIN devol_grupo AS dg ON p.codigoProduto = dg.codigoProduto

		ORDER BY 
			valorLiquidoTotal DESC	
/**/			
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END