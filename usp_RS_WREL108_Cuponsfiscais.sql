/*
====================================================================================================================================================================================
WREL108 - Cupons fiscais GZ
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
26/03/2026 WILLIAM
	- Correcao no filtro por valor, estava filtrando a nivel de itens, e o correto é filtrar a nivel de cupom, somando o valor total do cupom para comparar com o valor do filtro;
	- Inclusao de contagem de linhas por cupom, onde no ReportingServices iremos contabilizar comente os registros = 1, assim saberemos quantos cupons forma listados;
10/03/2026 WILLIAM
	- Inclusao do parametro de entrada @pValor, para permitir filtrar cupons a partir de um valor, para facilitar a encontrar o cupom quando nao se tem o numero dele;
24/04/2025 WILLIAM
	- Troca da SP "usp_Get_VendasCupons" pela "usp_Get_Vendas_MovCaixaGZ", que foi apenas renomeada;
25/02/2025 WILLIAM
	- Retirada das SPs "usp_movcaixa" e "usp_movcaixagz", pois foi unificado os dados entre a GZ e Integros na tabela "movcaixagz", 
	usando em substiuicao, a SP "usp_Get_VendasCuons";
	- Alteracao dos tipos dos parametros de entrada:
		- @CXA varchar(50), pois vai aceitar multi valor no ReportServer;		
24/02/2025 WILLIAM
	- Atribuicao de valores default para os parametros de entrada, para facilitar a chamada, permitindo preencher somente o que for necessario para o momento;	
	- Retirada dos filtros por COO e ECF, não utilizados mais;
	- Refinamento do codigo;
	- Uso da SP "usp_Get_CodigosProdutos"
06/01/2025 WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;	
	- Uso da SP "sp_movcaixa" pela "usp_movcaixa";
	- Uso da SP "sp_movcaixagz" pela "usp_movcaixagz";
	- Retirada da varificacao se empresa tem frente de loja, ja que o rel. so vai ser implantado em empresas com frente de loja;
====================================================================================================================================================================================
*/
CREATE PROCEDURE [dbo].[usp_RS_WREL108_Cuponsfiscais]
--ALTER PROCEDURE [dbo].[usp_RS_WREL108_Cuponsfiscais]
	@empcod smallint,
	@dataDe datetime = null,
	@dataAte datetime = null,
	@CXA varchar(100) = '' ,
	@CUP int = 0,	
	@CGC varchar(30) = '',
	@NFSNUM int = 0,
	@PROCOD varchar(15) = '',
	@PRODES varchar(60) = '',
	@marcod int = 0,
	@marcanom varchar(60) = '',
	@pValor decimal(18,2) = 0,
	@CANCELADO char(1) = ''
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @Data_De datetime, @Data_Ate datetime, @Caixas varchar(100), @NumCUP int, @CNPJ varchar(30), @NumNota int, @Produto varchar(15), @ProdutoDesc varchar(60),
			@Marca int, @MarcaNome varchar(60), @CupomCancelado char(1), @valor decimal(18,2),
			@empresaTBS010 smallint;

	-- Desativando a deteccao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Data_De = (SELECT ISNULL(@dataDe, '17530101'));;
	SET @Data_Ate = (SELECT ISNULL(@dataAte, GETDATE()));
	SET @Caixas = @CXA;	
	SET @NumCUP = @CUP;
	SET @CNPJ = @CGC;
	SET @NumNota = @NFSNUM;
	SET @Produto = @PROCOD;
	SET @ProdutoDesc = @PRODES;
	SET @Marca = @marcod;
	SET @MarcaNome = @marcanom;
	SET @valor = @pValor;
	SET @CupomCancelado = UPPER(@CANCELADO);

-- Verificacao de tabela compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os codigos dos produtos via SP
	
	IF OBJECT_ID('tempdb.dbo.#CODIGOSPRO') IS NOT NULL
		DROP TABLE #CODIGOSPRO;

	CREATE TABLE #CODIGOSPRO (PROCOD CHAR(15))

	INSERT INTO #CODIGOSPRO
	EXEC usp_Get_CodigosProdutos @codigoEmpresa, @Produto, @ProdutoDesc, @Marca, @MarcaNome

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Refinamento dos produtos

	IF OBJECT_ID('tempdb.dbo.#TBS010') IS NOT NULL
		DROP TABLE #TBS010;

	SELECT 
		PROCOD,
		PRODES,
		PROUM1

	INTO #TBS010 FROM TBS010 (NOLOCK) 

	WHERE 
		PROEMPCOD = @empresaTBS010 AND
		PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #CODIGOSPRO)	

--	SELECT * FROM #TBS010;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os registros dos cupons da tabela movcaixagz, via SP que gera a tabela global ##MOVCAIXAGZ

	EXEC usp_Get_Vendas_MovCaixaGZ @Data_De, @Data_Ate, @Caixas, '01,13', @CupomCancelado

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Colocar os cnpj em todas as linhas dos cupons 

	UPDATE ##MOVCAIXAGZ SET
		cgc = 	CASE WHEN LEN(b.cgc) > 15 
				THEN
					SUBSTRING(ISNULL(REPLACE(REPLACE(REPLACE(b.cgc,'.',''),'/',''),'-',''),''), 2, 20)
				ELSE
					ISNULL(REPLACE(REPLACE(REPLACE(b.cgc,'.',''),'/',''),'-',''),'')
				END
	FROM ##MOVCAIXAGZ a 
		LEFT JOIN 
				(
				SELECT 	
					cgc,
					loja,
					cupom,
					caixa,
					nfce_chave			
				FROM ##MOVCAIXAGZ
			
				WHERE
					cgc <> ''
			
				group by 
				cgc, 
				loja, 
				cupom,  
				caixa,
				nfce_chave 
				) AS b ON a.loja = b.loja and a.cupom = b.cupom and a.caixa = b.caixa and a.nfce_chave collate database_default = b.nfce_chave 

-- SELECT * FROM #MOVCAIXAGZ where cgc <> ''
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtra produtos nos registros do movcaixagz

	IF OBJECT_ID('tempdb.dbo.#CUPONS') IS NOT NULL
	   DROP TABLE #CUPONS;
		
	SELECT 
		IIF(cancelado = 'S', 'S', 'N') AS M2_CAN,
		cgc AS M2_CGC,
		cupom AS M2_CUP,
		caixa AS M2_CXA,
		data AS M2_DAT,
		item AS M2_ITE,
		cdprod AS PROCOD,
		B.PRODES,
		B.PROUM1,		
		valortot AS M2_VALBRU,
		acrescupom AS M2_ACRCUP,
		desccupom AS M2_DESCUP,
		abatpgto AS M2_ABT,
		valorliq AS M2_LIQUIDO,
		quant AS M2_QTD,
		numeronf AS NFSNUM,		
		vendedor AS ENFVENCOD,
		ISNULL(ENFDATEMI, '17530101') AS ENFDATEMI,
		ISNULL(VENNOM, '') AS VENNOM,
		SUM(valorliq) OVER(PARTITION BY cupom, caixa, data) AS valorTotal
	INTO #CUPONS FROM ##MOVCAIXAGZ A
		INNER JOIN #TBS010 B (NOLOCK) ON cdprod COLLATE DATABASE_DEFAULT = PROCOD
		LEFT JOIN TBS080 C (NOLOCK) ON ENFNUM = numeronf AND SNESER = serienf
		LEFT JOIN TBS004 D (NOLOCK) ON VENCOD = vendedor

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Nesse ponto apagar as tabelas temporarias sem uso

	DROP TABLE ##MOVCAIXAGZ;
	DROP TABLE #TBS010;
	DROP TABLE #CODIGOSPRO;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final 
	SELECT 
		*,
		CASE WHEN M2_CAN = 'S' THEN M2_LIQUIDO ELSE 0 END AS ValorCancelado,
		CASE WHEN M2_CAN = 'N' THEN M2_LIQUIDO ELSE 0 END AS ValorNormal,
		ROW_NUMBER() OVER(PARTITION BY M2_CUP, M2_CXA, M2_DAT ORDER BY M2_ITE DESC) AS RN		
	FROM #CUPONS

	WHERE 
		M2_CUP = CASE WHEN @NumCUP = 0 THEN M2_CUP ELSE @NumCUP END AND 
		NFSNUM = CASE WHEN @NumNota = 0 THEN NFSNUM ELSE @NumNota END AND 
		M2_CGC = CASE WHEN @CNPJ = '' THEN M2_CGC ELSE @CNPJ END
		AND valorTotal >= @valor
	
/**/		
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
END
