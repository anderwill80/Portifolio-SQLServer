/*
====================================================================================================================================================================================
WREL001 - Acompanhamento Pendente x Compras
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
31/03/2026 WILLIAM
	- Correcao alterando o parametro da funcao REPLACE() de "/" para ";", da informacao obtida do parametro 1269;
21/01/2025 WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;
************************************************************************************************************************************************************************************
*/
--CREATE PROCEDURE [dbo].[usp_RS_AcompanhamentoPendentexCompras]
ALTER PROCEDURE [dbo].[usp_RS_AcompanhamentoPendentexCompras]
	@empcod smallint
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint,
			@LESCOD VARCHAR(25), @A VARCHAR(150);
			
	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;

	SET @LESCOD = RTRIM(LTRIM((select REPLACE(PARVAL,';',',') from TBS025 NOLOCK WHERE PARCHV = 1269)))

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	
	SET @A = 'SELECT DISTINCT LESCOD FROM TBS034 NOLOCK WHERE LESCOD IN ('+RTRIM(LTRIM(@LESCOD))+')'

	--SELECT @A;

	IF object_id('TempDB.dbo.#LESCOD') is not null
		DROP TABLE #LESCOD;

	CREATE TABLE #LESCOD (LESCOD INT)

	INSERT INTO #LESCOD
	EXEC(@A)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os pedidos com os produtos pendentes
	
	IF object_id('tempdb.dbo.#PEN1') IS NOT NULL
		DROP TABLE #PEN1;

	SELECT
		'PDV' AS NOME,
		PRPNUM AS PRPNUM,
		A.PRPITEM AS PRPITEM,
		PROEMPCOD,
		PROCOD,
		-- PRPPRODES AS PRODES,
		PRPQTD*PRPQTDEMB AS TB_ESTQTDPEN,
		PRPESTLOC AS LESCOD,
		ISNULL((SELECT PDVPRECUS FROM TBS0551 F (NOLOCK) WHERE A.PRPNUM = F.PDVNUM AND A.PROCOD = F.PROCOD AND A.PRPITEM = F.PDVITEM),0) * PRPQTD as T4_TOTCUSTO, 
		PRPPRELIQ*PRPQTD AS T4_TOTMARCA,
		dbo.FCNDIASUTEIS((SELECT PDVDATCAD FROM TBS055 B (NOLOCK) WHERE A.PRPNUM = B.PDVNUM),GETDATE()) AS PENDIA,
		CONVERT(DECIMAL(10,4),ROUND(A.PRPPRELIQ / PRPQTDEMB,4)) AS PREUNI  -- PREÇO POR UNIDADE LIQUIDO / QTDEMB = PREÇO UNITARIO
		-- A.PRPQTDEMB AS EMB 
	INTO #PEN1 FROM TBS058 A (NOLOCK) 

	WHERE 
		PRPSIT = 'P' AND 
		PRPMOVEST='S' AND
		PRPESTLOC IN (SELECT LESCOD FROM #LESCOD)

	UNION 
	SELECT 
		'SDC' AS NOME,
		A.SDCNUM AS PRPNUM,
		A.SDCITE AS PRPITEM,
		PROEMPCOD,
		PROCOD,
		-- SDCPRODES AS PRODES,
		(SDCQTDPED-SDCQTDATD-SDCQTDRES) * SDCQTDEMB AS TB_ESTQTDPEN,
		LESCOD ,
		0,
		0,
		dbo.FCNDIASUTEIS(B.SDCDATCAD,GETDATE()) AS PENDIA,
		0
		-- A.SDCQTDEMB
	FROM TBS0761 A (NOLOCK) 
		LEFT JOIN TBS076 B (NOLOCK) ON A.SDCNUM = B.SDCNUM

	WHERE
		SDCPEN = 'S' AND 
		SDCQTDPED > (SDCQTDBAI +SDCQTDRES) AND
		LESCOD IN (SELECT LESCOD FROM #LESCOD)

	-- select * FROM #PEN1
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CRIANDO TABELA DE COMPRAS EM ABERTO E COM VALOR TOTAL 

	IF object_id('tempdb.dbo.#CMP1') IS NOT NULL
		DROP TABLE #CMP1;
	
	SELECT 
		D.LESCOD,
		D.PROCOD,
		SUM(dbo.PDCTOTITE(D.PDCEMPCOD,D.PDCNUM,PDCITE)) AS PDCVAL,
		SUM((PDCQTD * PDCQTDEMB)) AS PDCQTD
	INTO #CMP1 FROM TBS0451 D (NOLOCK) 
		LEFT JOIN TBS045 E (NOLOCK) ON  D.PDCNUM = E.PDCNUM

	WHERE
		(PDCQTD - PDCQTDENT - PDCQTDRES ) > 0 AND PDCBLQ ='N' AND 
		LESCOD IN (SELECT LESCOD FROM #LESCOD) AND 
		D.PROCOD IN (SELECT DISTINCT PROCOD FROM #PEN1)
 
	GROUP BY
		D.PROCOD, D.LESCOD

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
		SUM(ESTQTDATU-ESTQTDRES) AS ESTQTDDIS, 
		CASE WHEN ISNULL((SELECT SUM(PDCQTD)       FROM #CMP1 C WHERE A.PROCOD = C.PROCOD AND A.ESTLOC = C.LESCOD),0) + SUM(ESTQTDATU-ESTQTDRES) >=
				  ISNULL((SELECT SUM(TB_ESTQTDPEN) FROM #PEN1 B WHERE A.PROCOD = B.PROCOD AND A.ESTLOC = B.LESCOD),0)
			THEN 0
			ELSE 1
		END SIT
	INTO #CMP FROM TBS032 A (NOLOCK)

	WHERE
		A.PROCOD IN (SELECT DISTINCT PROCOD FROM #PEN1) AND 
		ESTLOC IN (SELECT LESCOD FROM #LESCOD)
	GROUP BY
		A.PROCOD,
		ESTLOC

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CRIA A ORDERNAÇÃO PARA ATENDIMENTO AGRUPADO POR PRODUTO E DATA ASCENDENTE, PEGANDO O QUE ESTÁ DISPONIVEL E SOMANDO COM A QUANTIDADE EM COMPRAS

	IF object_id('tempdb.dbo.#P') IS NOT NULL
		DROP TABLE #P
	
	SELECT 
		SIT,
		ISNULL(ESTQTDCMP,0) + ISNULL(ESTQTDDIS,0) AS ESTQTDCMP,
		CONVERT(DECIMAL(10,4),0) AS CMP,
		CONVERT(DECIMAL(10,4),0) AS CMPMAIS,
		CONVERT(DECIMAL(10,4),0) AS COMPRADO,
		rank() OVER (ORDER BY PRPNUM,PRPITEM,A.PROCOD) AS ID, 
		rank() OVER (ORDER BY A.PROCOD,PRPNUM) AS IDPRPNUM,
		A.* 
	INTO #P FROM #PEN1 A
		LEFT JOIN #CMP B ON A.PROCOD = B.PROCOD AND A.LESCOD = B.ESTLOC 
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TUDO QUE ESTIVER COM SIT = 0 , SIGNIFICA QUE JA FOI COMPRADO OU TEM EM ESTOQUE DISPONIVEL OU A SOMA DE AMBOS ATENDE, ENTÃO A QUANTIDADE COMPRADA É IGUAL A PENDENCIA

	UPDATE #P SET 
		COMPRADO = TB_ESTQTDPEN
	WHERE 
		SIT = 0

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TUDO QUE ESTIVER COM COMPRAS+SALDO <= 0 , SIGNIFICA QUE É NECESSARIO COMPRAR NO MINIMO A QUANTIDADE PENDENTE

	UPDATE #P SET
		CMPMAIS = TB_ESTQTDPEN
	WHERE 
		SIT = 1 AND
		ESTQTDCMP <= 0 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TUDO QUE ESTIVER COM COMPRAS+SALDO > 0, POREM NÃO ATENDE TOTALMENTE A PENDENCIA, PRECISO ACUMULAR A PENDENCIA PARA SABER QUAL PRODUTO NÃO ATENDE

	UPDATE #P SET
		CMP = (SELECT sum(TB_ESTQTDPEN) FROM #P B  WHERE #P.IDPRPNUM >= B.IDPRPNUM AND #P.PROCOD = B.PROCOD AND #P.LESCOD = B.LESCOD)
	WHERE 
		SIT = 1 AND
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
		SIT = 1 AND
		ESTQTDCMP > 0 

	-- select * FROM #P ORDER BY IDPRPNUM

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- VERIFICA SE ATENDE OU NÃO

	IF object_id('tempdb.dbo.#PEN') IS NOT NULL
		DROP TABLE #PEN

	SELECT 
		CASE WHEN COMPRADO >= TB_ESTQTDPEN THEN
			0 -- ATENDE
		ELSE 
			1 -- NÃO ATENDE
		END AS SITUACAO,
		*
	INTO #PEN FROM #P AS TA

	-- SELECT * FROM #PEN WHERE PROCOD IN ( SELECT PROCOD FROM #PEN WHERE ESTQTDCMP < TB_ESTQTDPEN AND ESTQTDCMP > 0 )

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- pedidos de vendas pendentes TOTAL

	; WITH PEN AS(select ROUND(SUM(T4_TOTMARCA),2) as VALPEN ,count(DISTINCT PROCOD) AS CONTPEN from #PEN (nolock) ),
				
	-- pedidos de vendas pendentes com compras + SALDO > 0 , ATENDE

	PENCOM AS (select ROUND(SUM(COMPRADO*PREUNI),2) AS VALPENCOM ,count(DISTINCT PROCOD) AS CONTPENCOM
				from #PEN A (nolock)  
						
				where 
				COMPRADO > 0  ) ,
				
	-- pedidos de vendas pendentes restante, NAO ATENDE

	PENSEMCOM AS (select ROUND(SUM(CMPMAIS*PREUNI),2) AS VALPENSEMCOM ,count(DISTINCT PROCOD) AS CONTPENSEMCOM
				from #PEN A (nolock)  
		
				where 
				CMPMAIS > 0 ) , 


	-------------------------------------------------------------------------------------------------------------------------------------------------------------------

	-- período versus número de dias

	-- pedidos de vendas pendentes restante (realmente pendente, precisa comprar, ainda não foi comprado a quantidade total para atender a pendencia)

	-- até 2 dias
	PENDIAS2 AS (select count(DISTINCT PROCOD) AS ITENS  
			 
				 from #PEN A (nolock)
					 
				 where 
				 PENDIA BETWEEN 0 AND 2 AND 
				 CMPMAIS > 0) ,
	    
   

	-- de 3 a 7 dias
	PENDIAS37 AS (select count(DISTINCT PROCOD) AS ITENS  
			 
				 from #PEN A (nolock)
			 			 
				 where 
				 PENDIA BETWEEN 3 AND 7 AND 
				 CMPMAIS > 0) ,



	-- de 8 a 15 dias
	PENDIAS815 as (select count(DISTINCT PROCOD) AS ITENS  
			 
				 from #PEN A (nolock)
			 
				 where 
				 PENDIA BETWEEN 8 AND 15 AND 
				 CMPMAIS > 0) ,
	   
	   
	-- de 16 a 30 dias
	PENDIAS1630 AS (select count(DISTINCT PROCOD) AS ITENS  
			 
				 from #PEN A (nolock)
			 		 
				 where 
				 PENDIA BETWEEN 16 AND 30 AND 
				 CMPMAIS > 0) ,


	-- acima de 30 dias
	PENDIASMAIOR30 AS (select count(DISTINCT PROCOD) AS ITENS  
			 
				 from #PEN A (nolock)
			 
				 where
				 PENDIA > 30 AND
				 CMPMAIS > 0),

	-------------------------------------------------------------------------------------------------------------------------------

	-- pedidos de vendas pendentes com compras + SALDO > 0 (independete se atende ou não, pelo menos foi comprado uma parte)

	-- até 2 dias
	COMDIAS2 AS (select count(DISTINCT PROCOD) AS ITENS  
			 
				 from #PEN A (nolock)
			 
				 where 
				 PENDIA BETWEEN 0 AND 2 AND 
				 COMPRADO > 0) ,
			 
	-- de 3 a 7 dias
	COMDIAS37 AS (select COUNT(DISTINCT PROCOD) AS ITENS  
			 
				 from #PEN A (nolock)
			 		 
				 where 
				 PENDIA BETWEEN 3 AND 7 AND 
				 COMPRADO > 0),	

	-- de 8 a 15 dias
	COMDIAS815 AS (select COUNT(DISTINCT PROCOD) AS ITENS  
			 
				 from #PEN A (nolock)
			 		 
				 where 
				 PENDIA BETWEEN 8 AND 15 AND 
				 COMPRADO > 0),

	-- de 16 a 30 dias
	COMDIAS1630 AS (select COUNT(DISTINCT PROCOD) AS ITENS  
			 
				 from #PEN A (nolock)
			 			 
				 where 
				 PENDIA BETWEEN 16 AND 30 AND 
				 COMPRADO > 0),

	-- acima de 30 dias
	COMDIASMAIOR30 AS (select COUNT(DISTINCT PROCOD) AS ITENS  
			 
				 from #PEN A (nolock)
					 
				 where 
				 PENDIA > 30 AND 
				 COMPRADO > 0) 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final
	   
	SELECT --TOP 1 
		'ND' AS UNIDADE,
		A.VALPEN, 
		A.CONTPEN, 
		B.VALPENCOM,
		B.CONTPENCOM, 
		D.VALPENSEMCOM, 
		D.CONTPENSEMCOM, 
		E.ITENS AS 'PEN 2',
		F.ITENS AS 'PEN 3 A 7',
		G.ITENS AS 'PEN 8 A 15',
		H.ITENS AS 'PEN 16 A 30', 
		I.ITENS AS 'PEN +30',
		J.ITENS AS 'COM 2',
		L.ITENS AS 'COM 3 A 7',
		N.ITENS AS 'COM 8 A 15',
		P.ITENS AS 'COM 16 A 30',
		R.ITENS AS 'COM +30'

	FROM PEN A, PENCOM B, PENSEMCOM D , PENDIAS2 E, PENDIAS37 F , PENDIAS815 G, PENDIAS1630 H, PENDIASMAIOR30 I, COMDIAS2 J, COMDIAS37 L, 
	COMDIAS815 N, COMDIAS1630 P,COMDIASMAIOR30 R

END