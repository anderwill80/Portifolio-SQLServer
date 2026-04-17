/*
====================================================================================================================================================================================
WREL042 - Pendencias Com Compras-Saldo e Sem Compras
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
23/01/2025 - WILLIAM
	- Conversão do script SQL para StoredProcedure;
	- Inclusão do @empcod nos parâmetros de entrada da SP;	
	- Inclusão de filtros nas tabelas pela empresa, utilizando o parâmetro recebido via menu do Integros(@empcod), juntamente com a SP "usp_GetCodigoEmpresaTabela";
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_PendenciasComComprasSaldoSemCompras]
--ALTER PROCEDURE [dbo].[usp_RS_PendenciasComComprasSaldoSemCompras]
	@empcod smallint,
	@codigoproduto varchar(15),
	@descricaoproduto varchar(60),
	@PEDV int,
	@PEDC int,
	@DIAS int,
	@DIAS2 int,
	@DATPEN1 datetime,
	@DATAPEN2 datetime,
	@OPCAO int,
	@LOCAL char(3)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS002 smallint, @empresaTBS006 smallint, @empresaTBS010 smallint, @empresaTBS055 smallint,
			@empresaTBS045 smallint, @empresaTBS076 smallint,
			@PROCOD varchar(15), @PRODES varchar(60), @PDVNUM int, @PDCNUM int, @DIAS_De int, @DIAS_Ate int, @DATPEN_De datetime, @DATPEN_Ate datetime,
			@OpcaoSit int, @LocalPend char(3),
			@LESCOD varchar(254),
			@ParmDef nvarchar(500), @cmdSQL nvarchar(MAX);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @PROCOD = @codigoproduto;
	SET @PRODES = RTRIM(LTRIM(UPPER(@descricaoproduto)));
	SET @PDVNUM = @PEDV;
	SET @PDCNUM = @PEDC;
	SET @DIAS_De = @DIAS;
	SET @DIAS_Ate = IIF(@DIAS2 = 0, 10000, @DIAS2);
	SET @DATPEN_De = (SELECT ISNULL(@DATPEN1, '17530101'));
	SET @DATPEN_Ate = (SELECT ISNULL(@DATAPEN2, GETDATE()));
	SET @OpcaoSit = @OPCAO;
	SET @LocalPend = @LOCAL;

-- Obtem parametros
	-- Locais de estoque
	SET @LESCOD = RTRIM(LTRIM((SELECT REPLACE(PARVAL,'/', ',') FROM TBS025 NOLOCK WHERE PARCHV = 1269)))

-- Verificar se a tabela é compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS006', @empresaTBS006 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS045', @empresaTBS045 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS055', @empresaTBS055 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS076', @empresaTBS076 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Cria tabela com os locais de estoque obtidos do parametro
	
	SET @cmdSQL = 'SELECT DISTINCT LESCOD FROM TBS034 NOLOCK WHERE LESCOD IN ('+RTRIM(LTRIM(@LESCOD))+')'

	IF object_id('TempDB.dbo.#LESCOD') IS NOT NULL
		DROP TABLE #LESCOD;

	CREATE TABLE #LESCOD (LESCOD INT)
	INSERT INTO #LESCOD
	EXEC(@cmdSQL)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os itens pendentes da TBS058

	IF OBJECT_ID('TEMPDB.DBO.#PEN1') IS NOT NULL
		DROP TABLE #PEN1

	SELECT
		'PDV' AS NOME,
		(SELECT RTRIM(LTRIM(STR(CLICOD))) + ' - ' + RTRIM(LTRIM(CLINOM)) FROM TBS002 C (NOLOCK) WHERE CLIEMPCOD = @empresaTBS002 AND A.PRPCLICOD = C.CLICOD) AS CLINOM,
		PRPNUM AS PRPNUM,
		A.PRPITEM AS PRPITEM,
		PROEMPCOD,
		PROCOD,
		PRPPRODES AS PRODES,
		ISNULL((SELECT PROUM1 FROM TBS010 B (NOLOCK) WHERE PROEMPCOD = @empresaTBS010 AND A.PROCOD = B.PROCOD),'') AS PROUM1,
		PRPQTD*PRPQTDEMB AS TB_ESTQTDPEN,
		PRPESTLOC AS LESCOD,
		ISNULL((SELECT PDVPRECUS FROM TBS0551 F (NOLOCK) WHERE PRPEMP = PDVEMPCOD AND A.PRPNUM = F.PDVNUM AND A.PROCOD = F.PROCOD AND A.PRPITEM = F.PDVITEM),0) * PRPQTD as T4_TOTCUSTO, 
		ISNULL((SELECT PDVDATCAD FROM TBS055 B (NOLOCK) WHERE PRPEMP = PDVEMPCOD AND A.PRPNUM = B.PDVNUM), '') AS PDVDATCAD,
		PRPPRELIQ*PRPQTD AS T4_TOTMARCA,
		dbo.FCNDIASUTEIS(ISNULL((SELECT PDVDATCAD FROM TBS055 B (NOLOCK) WHERE PRPEMP = PDVEMPCOD AND A.PRPNUM = B.PDVNUM),''),GETDATE()) AS PENDIA,
		CONVERT(DECIMAL(10,4),ROUND(A.PRPPRELIQ / PRPQTDEMB,4)) AS PREUNI  -- PREÇO POR UNIDADE LIQUIDO / QTDEMB = PREÇO UNITARIO 
	INTO #PEN1 FROM TBS058 A (NOLOCK) 

	WHERE 
		PRPEMP = @empresaTBS055 AND
		PRPSIT    = 'P' AND 
		PRPMOVEST = 'S' AND
		PRPESTLOC IN (SELECT LESCOD FROM #LESCOD)
		
	UNION 
	SELECT 
		'SDC' AS NOME,
		(SELECT RTRIM(LTRIM(STR(CLICOD))) + ' - ' + RTRIM(LTRIM(CLINOM)) FROM TBS002 D (NOLOCK) WHERE CLIEMPCOD = @empresaTBS002 AND B.CLICOD = D.CLICOD) AS CLINOM,
		A.SDCNUM AS PRPNUM,
		A.SDCITE AS PRPITEM,
		PROEMPCOD,
		PROCOD,
		SDCPRODES AS PRODES,
		ISNULL((SELECT PROUM1 FROM TBS010 C (NOLOCK) WHERE PROEMPCOD = @empresaTBS010 AND A.PROCOD = C.PROCOD),'') AS PROUM1,
		(SDCQTDPED-SDCQTDATD-SDCQTDRES) * SDCQTDEMB AS TB_ESTQTDPEN,
		LESCOD ,
		0,
		SDCDATCAD,
		0,
		dbo.FCNDIASUTEIS(B.SDCDATCAD,GETDATE()) AS PENDIA,
		0
	FROM TBS0761 A (NOLOCK) 
		LEFT JOIN TBS076 B (NOLOCK) ON A.SDCEMPCOD = B.SDCEMPCOD AND A.SDCNUM = B.SDCNUM

	WHERE
		A.SDCEMPCOD = @empresaTBS076 AND
		SDCPEN    = 'S' AND 
		SDCQTDPED > (SDCQTDBAI +SDCQTDRES) AND
		LESCOD    IN (SELECT LESCOD FROM #LESCOD)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CRIANDO TABELA DE COMPRAS EM ABERTO E COM VALOR TOTAL 

	IF object_id('tempdb.dbo.#CMP1') IS NOT NULL
	   DROP TABLE #CMP1;
	
	SELECT 
		(SELECT RTRIM(LTRIM(STR(FORCOD))) + ' - ' + RTRIM(LTRIM(FORNOM)) FROM TBS006 A (NOLOCK) WHERE FOREMPCOD = @empresaTBS006 AND E.FORCOD = A.FORCOD) AS FORNOM,
		E.PDCNUM,
		D.PROCOD,
		D.LESCOD,
		SUM(dbo.PDCTOTITE(D.PDCEMPCOD,D.PDCNUM,PDCITE)) AS PDCVAL,
		SUM((PDCQTD * PDCQTDEMB)) AS PDCQTD,
		E.PDCDATCAD AS PDCDAT,
		CASE WHEN CONVERT(CHAR(10),E.PDCDATPEN,103) = '01/01/1753'
			THEN ''
			ELSE CONVERT(CHAR(10),E.PDCDATPEN,103) 
		END AS PDCENT
	
	INTO #CMP1 FROM TBS0451 D (NOLOCK)
		LEFT JOIN TBS045 E (NOLOCK) ON E.PDCEMPCOD = D.PDCEMPCOD AND D.PDCNUM = E.PDCNUM
	
	WHERE
		D.PDCEMPCOD = @empresaTBS045 AND
		(PDCQTD - PDCQTDENT - PDCQTDRES ) > 0 AND 
		PDCBLQ ='N' AND
		D.PROCOD IN (SELECT DISTINCT PROCOD FROM #PEN1) AND 
		D.LESCOD IN (SELECT LESCOD FROM #LESCOD)
	
	GROUP BY
		E.PDCNUM,D.PROCOD,E.PDCDATCAD,E.PDCDATPEN,D.LESCOD, E.FORCOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- SALDO, PEGO O SALDO PENDENTE DA SOMA DA TBS058 E TBS0761 E O SALDO DE COMPRAS DOS PEDIDOS DE COMPRAS EM ABERTO

	IF object_id('tempdb.dbo.#CMP') IS NOT NULL
	   DROP TABLE #CMP;

	SELECT
		ESTLOC, 
		PROCOD,
		ISNULL((SELECT SUM(TB_ESTQTDPEN) FROM #PEN1 B WHERE A.PROCOD = B.PROCOD AND A.ESTLOC = B.LESCOD),0) AS ESTQTDPEN,
		ISNULL((SELECT SUM(PDCQTD)       FROM #CMP1 C WHERE A.PROCOD = C.PROCOD AND A.ESTLOC = C.LESCOD),0) AS ESTQTDCMP,
		SUM(ESTQTDRES) AS ESTQTDRES,
		SUM(ESTQTDATU) AS ESTQTDATU,
		SUM(ESTQTDATU-ESTQTDRES) AS ESTQTDDIS , 

		-- VERIFICA ATENDIMENTO PARCIAL 

		CASE WHEN ISNULL((SELECT SUM(PDCQTD)       FROM #CMP1 C WHERE A.PROCOD = C.PROCOD AND A.ESTLOC = C.LESCOD),0) + SUM(ESTQTDATU-ESTQTDRES) <
				  ISNULL((SELECT SUM(TB_ESTQTDPEN) FROM #PEN1 B WHERE A.PROCOD = B.PROCOD AND A.ESTLOC = B.LESCOD),0)  AND 
				  ISNULL((SELECT SUM(PDCQTD)       FROM #CMP1 C WHERE A.PROCOD = C.PROCOD AND A.ESTLOC = C.LESCOD),0) + SUM(ESTQTDATU-ESTQTDRES) > 0
			THEN 0
			ELSE 1 
		END AS SITUACAO_PAR,

		-- VERIFICA SE DIPONIVEL + COMPRAS ATENDE

		CASE WHEN ISNULL((SELECT SUM(PDCQTD)       FROM #CMP1 C WHERE A.PROCOD = C.PROCOD AND A.ESTLOC = C.LESCOD),0) + SUM(ESTQTDATU-ESTQTDRES) >=
				  ISNULL((SELECT SUM(TB_ESTQTDPEN) FROM #PEN1 B WHERE A.PROCOD = B.PROCOD AND A.ESTLOC = B.LESCOD),0) -- AND 
				  -- ISNULL((SELECT SUM(PDCQTD)       FROM #CMP1 C WHERE A.PROCOD = C.PROCOD AND A.ESTLOC = C.LESCOD),0) > 0
			THEN 0
			ELSE 1 
		END AS SITUACAO_ATE,

		-- VERIFICA O QUE NÃO ATENDE 

		CASE WHEN ISNULL((SELECT SUM(PDCQTD)       FROM #CMP1 C WHERE A.PROCOD = C.PROCOD AND A.ESTLOC = C.LESCOD),0) + SUM(ESTQTDATU-ESTQTDRES) <
				  ISNULL((SELECT SUM(TB_ESTQTDPEN) FROM #PEN1 B WHERE A.PROCOD = B.PROCOD AND A.ESTLOC = B.LESCOD),0) AND 
				  ISNULL((SELECT SUM(PDCQTD)       FROM #CMP1 C WHERE A.PROCOD = C.PROCOD AND A.ESTLOC = C.LESCOD),0) + SUM(ESTQTDATU-ESTQTDRES) <= 0
			THEN 0
			ELSE 1 
		END AS SITUACAO_NATE
	INTO #CMP FROM TBS032 A (NOLOCK)

	WHERE
		PROEMPCOD = @empresaTBS010 AND
		A.PROCOD IN (SELECT DISTINCT PROCOD FROM #PEN1) AND 
		ESTLOC IN (SELECT LESCOD FROM #LESCOD)
	GROUP BY
		A.PROCOD,
		ESTLOC

	--SELECT * FROM #CMP
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CRIA A ORDERNAÇÃO PARA ATENDIMENTO, DO MAIS VELHO PARA O MAIS NOVO, PEGANDO O QUE ESTÁ DISPONIVEL E SOMANDO COM A QUANTIDADE EM COMPRAS

	IF object_id('tempdb.dbo.#P') IS NOT NULL
		DROP TABLE #P;
	
	SELECT 
		CASE WHEN SITUACAO_PAR = 0 
			THEN 'PARCIAL'
			ELSE
				CASE WHEN SITUACAO_NATE = 0
					THEN 'NAO ATENDE'
					ELSE
						CASE WHEN SITUACAO_ATE = 0 
							THEN 'ATENDE'
							ELSE ''
						END
				END
		END AS SITUACAO,
		SITUACAO_ATE,
		ISNULL(ESTQTDDIS,0) AS ESTQTDDIS,
		ISNULL(ESTQTDCMP,0) AS ESTQTDCMP1,
		ISNULL(ESTQTDCMP,0) + ISNULL(ESTQTDDIS,0) AS ESTQTDCMP, -- ESTOQUE EM COMPRAS = COMPRAS + DISPONIVEL
		CONVERT(DECIMAL(10,4),0) AS CMP,
		CONVERT(DECIMAL(10,4),0) AS CMPMAIS,
		CONVERT(DECIMAL(10,4),0) AS COMPRADO,
		rank() OVER (ORDER BY PRPNUM,PRPITEM,A.PROCOD) AS ID, 
		rank() OVER (ORDER BY A.PROCOD,PRPNUM) AS IDPRPNUM,
		A.* 
	INTO #P	FROM #PEN1 A
		LEFT JOIN #CMP B ON A.PROCOD = B.PROCOD AND A.LESCOD = B.ESTLOC 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TUDO QUE ESTIVER COM SIT = 0 , SIGNIFICA QUE JA FOI COMPRADO OU TEM EM ESTOQUE DISPONIVEL OU A SOMA DE AMBOS ATENDE, ENTÃO A QUANTIDADE COMPRADA É IGUAL A PENDENCIA

	UPDATE #P SET 
	COMPRADO = TB_ESTQTDPEN
	WHERE 
	SITUACAO_ATE = 0

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TUDO QUE ESTIVER COM COMPRAS+SALDO <= 0 , SIGNIFICA QUE É NECESSARIO COMPRAR NO MINIMO A QUANTIDADE PENDENTE

	UPDATE #P SET
	CMPMAIS = TB_ESTQTDPEN

	WHERE 
	SITUACAO_ATE = 1 and 
	ESTQTDCMP <= 0 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TUDO QUE ESTIVER COM COMPRAS+SALDO > 0, POREM NÃO ATENDE TOTALMENTE A PENDENCIA, PRECISO ACUMULAR A PENDENCIA PARA SABER QUAL PRODUTO NÃO ATENDE

	UPDATE #P SET
	CMP = (SELECT sum(TB_ESTQTDPEN)
			FROM #P B 
			WHERE #P.IDPRPNUM >= B.IDPRPNUM AND #P.PROCOD = B.PROCOD AND #P.LESCOD = B.LESCOD)
	WHERE 
	SITUACAO_ATE = 1 and 
	ESTQTDCMP > 0 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- COM A PENDENCIA ACUMULADA, VOU DIMINIR DO COMPRAS+SALDO, CASO FOR >= 0, SIGNIFICA QUE NÃO PRECISA COMPRAR, SE NÃO PENDENCIA ACUMULADA - COMPRAS+SALDO, 
	-- TEREI O NUMERO EXATO DO QUE PRECISO COMPRAR
	-- A QUANTIDADE COMPRADA SERÁ IGUAL A CASO COMPRAS+SALDO - ACUMULADO DA PENDENCIA >= 0 SIGNIFICA QUE ATENDE A PENDENCIA DO ITEM, ENTÃO SERÁ IGUAL A QUANTIDADE PENDENTE
	-- SE NÃO PRECISO SABER QUANTO COMPREI ATÉ O MOMENTO, ENTÃO COMPRAS+SALDO - ACUMULADO PENDENCIA + PENDENCIA DO ITEM

	UPDATE #P SET 
	CMPMAIS = (SELECT CASE WHEN ESTQTDCMP - CMP >= 0 THEN 0 ELSE CMP - ESTQTDCMP END),
	COMPRADO = (SELECT
				--CASE WHEN ESTQTDCMP > 0 
					--THEN 
						CASE WHEN ESTQTDCMP - CMP >= 0
							THEN TB_ESTQTDPEN 
							ELSE ESTQTDCMP - CMP +  TB_ESTQTDPEN 
						END
					--ELSE 0
				-- END
				)
	WHERE 
	SITUACAO_ATE = 1 AND
	ESTQTDCMP > 0
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF object_id('tempdb.dbo.#PEN') IS NOT NULL
		DROP TABLE #PEN;
	
	SELECT 
		CASE WHEN ESTQTDCMP > 0 -- AND CMPMAIS < TB_ESTQTDPEN
			THEN 
				CASE WHEN CMPMAIS = TB_ESTQTDPEN
					THEN 'NAO ATENDE'
					ELSE 
						CASE WHEN CMPMAIS < TB_ESTQTDPEN AND CMPMAIS > 0 
							THEN 'PARCIAL'
							ELSE 'ATENDE'
						END
				END
			ELSE 'NAO ATENDE'
		END AS SITUACAOitem,
		*
	INTO #PEN FROM #P A

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF object_id('tempdb.dbo.#PENDENCIA') IS NOT NULL
		DROP TABLE #PENDENCIA
	
	SELECT 
		SITUACAO, 
		SITUACAOitem,
		CMPMAIS, 						-- COMPRA MAIS 
		COMPRADO, 						-- QUANTIDADE QUE ATENDE O PEDIDO, JA FOI COMPRADO
		ESTQTDDIS, 						-- ESTOQUE DISPONIVEL
		ID AS PENIDE,					-- DO ITEM MAIS ANTIGO AO MAIS NOVO
		NOME AS PENNOM , 				-- SE É UM PDV OU SDC 
		CLINOM,
		PRPNUM AS PENNUM , 				-- NUMERO DO PEDIDO 
		LESCOD AS ESTLOC, 				-- LOCAL DO ESTOQUE
		PROCOD AS PENCOD ,				-- CODIGO DO PRODUTO
		PRODES AS PENDES ,				-- DESCRIÇÃO DO PRODUTO
		PROUM1 AS PENUN1 ,				-- MENOR UNIDADE DE EMBALAGEM
		PREUNI, 						-- PREÇO DA MENOR UNIDADE
		TB_ESTQTDPEN AS PENQTDITE ,		-- QTD DO ITEM PENDENTE
		T4_TOTMARCA AS PENVALITE ,		-- VALOR DO ITEM PENDENTE
		PDVDATCAD AS PENDAT ,			-- DATA DA PENDENCIA
		PENDIA,							-- DIAS NA PENDENCIA
		0 AS PDCQTD, 
		0 AS PDCVAL,
		'' AS PDCENT,
		CMPMAIS * PREUNI AS VALORPENDENTE,
		CMP								-- SOMA QUANTIDADE COMPRAS + SALDO DISPONIVEL
	INTO #PENDENCIA FROM  #PEN A
	
	WHERE 
		NOME = (CASE WHEN @LocalPend = '' THEN NOME ELSE @LocalPend END) AND	
		PRPNUM =(CASE WHEN @PDVNUM = 0 THEN PRPNUM ELSE @PDVNUM END) AND
		PENDIA BETWEEN @DIAS_De AND @DIAS_Ate AND
		PDVDATCAD BETWEEN @DATPEN_De AND @DATPEN_Ate

	UNION	
	SELECT  
		'', 						-- ATENDE, PARCIAL, NÃO ATENDE
		'',
		0, 						-- COMPRA MAIS 
		0, 							-- QUANTIDADE QUE ATENDE O PEDIDO, JA FOI COMPRADO
		(SELECT ESTQTDDIS FROM #CMP B WHERE A.PROCOD = B.PROCOD AND A.LESCOD = B.ESTLOC),   						-- ESTOQUE DISPONIVEL
		(SELECT MAX(ID) FROM #PEN) + 1 AS PENIDE,					-- DO ITEM MAIS ANTIGO AO MAIS NOVO
		'CMP' AS PENNOM , 				-- SE É UM PDV OU SDC 
		FORNOM AS CLINOM,
		PDCNUM AS PENNUM,
		LESCOD AS ESTLOC,
		PROCOD AS PENCOD ,				-- CODIGO DO PRODUTO
		'' AS PENDES ,				-- DESCRIÇÃO DO PRODUTO
		(SELECT TOP 1 PROUM1 FROM #PEN1 B WHERE A.PROCOD = B.PROCOD) AS PENUN1,
		0,
		0 AS PENQTDITE,
		0 AS PENVALITE ,
		PDCDAT AS PENDAT,
		0 AS PENDIA,
		PDCQTD, 
		PDCVAL,
		PDCENT,
		0 ,
		0
	FROM 
		#CMP1 A

	WHERE	
		PDCNUM = (CASE WHEN @PDCNUM = 0 THEN PDCNUM ELSE @PDCNUM END)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	

	IF @PDCNUM = 0 
	BEGIN
 
		UPDATE #PENDENCIA SET 
			SITUACAO = ISNULL((SELECT TOP 1 SITUACAO FROM #PENDENCIA A WHERE #PENDENCIA.PENCOD = A.PENCOD AND A.SITUACAO <> ''),''),
			PENDES = ISNULL((SELECT TOP 1 PENDES FROM #PENDENCIA A WHERE #PENDENCIA.PENCOD = A.PENCOD AND A.SITUACAO <> ''),'')
		WHERE 
			SITUACAO =''
	
		DELETE #PENDENCIA 
			WHERE PENDES = ''
	END
	ELSE 
	BEGIN 	
		DELETE #PENDENCIA
			WHERE PENCOD NOT IN (SELECT PENCOD FROM #PENDENCIA WHERE PENNOM = 'CMP')
	
		UPDATE #PENDENCIA SET 
			SITUACAO = ISNULL((SELECT TOP 1 SITUACAO FROM #PENDENCIA A WHERE #PENDENCIA.PENCOD = A.PENCOD AND A.SITUACAO <> ''),''),
			PENDES = ISNULL((SELECT TOP 1 PENDES FROM #PENDENCIA A WHERE #PENDENCIA.PENCOD = A.PENCOD AND A.SITUACAO <> ''),'')
		WHERE 
			SITUACAO =''	
	END 

	-- SELECT * FROM #PENDENCIA

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF @OpcaoSit = 1 -- TODOS OS PEDIDOS PENDENTES
	BEGIN
		SELECT 
			* 
		FROM
			#PENDENCIA 

		WHERE 
			PENDES LIKE(CASE WHEN @PRODES = '' THEN PENDES ELSE @PRODES END) AND
			PENCOD LIKE(CASE WHEN @PROCOD = '' THEN PENCOD ELSE @PROCOD END) 
	END 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF @OpcaoSit = 2 -- ESTÁ EM COMPRAS OU TEM NO ESTOQUE, PODE ATENDER PARCIALMENTE
	BEGIN
		SELECT 
			* 
		FROM
			#PENDENCIA 

		WHERE 
			PENDES LIKE(CASE WHEN @PRODES = '' THEN PENDES ELSE @PRODES END) AND
			PENCOD LIKE(CASE WHEN @PROCOD = '' THEN PENCOD ELSE @PROCOD END) AND 
			PENCOD IN ( SELECT PENCOD FROM #PENDENCIA WHERE COMPRADO > 0 )		
	END 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF @OpcaoSit = 3 -- PODE ESTAR EM COMPRAS OU NO ESTOQUE, MAS NÃO ATENDE
	BEGIN
		SELECT 
			* 
		FROM
			#PENDENCIA 

		WHERE 
			PENDES LIKE(CASE WHEN @PRODES = '' THEN PENDES ELSE @PRODES END) AND
			PENCOD LIKE(CASE WHEN @PROCOD = '' THEN PENCOD ELSE @PROCOD END) AND 
			PENCOD IN ( SELECT PENCOD FROM #PENDENCIA WHERE CMPMAIS > 0 )	
	END 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT 
		* 
	FROM #PENDENCIA
END

