/*
====================================================================================================================================================================================
WREL100 - NOTAS QUE COMPOEM O ICMS DE SAIDA POR CFOP
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
24/04/25 WILLIAM
	- Uso da SP "usp_Get_Vendas_MovCaixaGZ", para obter as vendas diretamente da tabela movcaixagz, em vez de usar a SP "usp_movcaixagz";
	- Refinamento do codigo;
28/03/25 WILLIAM
	- Uso da funcao ufn_Get_TemFrenteLoja(), para saber se empresa tem frente de loja;
	- Retirada da SP "usp_movcaixa", pois os dados foram unificados para o "usp_movcaixagz";
	- Refinamento do codigo;
18/12/2024 WILLIAM
	- Inclusao do @empcod nos parametros de entrada da SP;
	- Leitura do parametro 1136, para saber se empresa tem frente de loja, se tiver, o valor sera o CNPJ da empresa, que sera comparada com o CNPJ da TBS023;
====================================================================================================================================================================================
*/
--ALTER PROCEDURE [dbo].[usp_RS_NotasCompoemICMSSaidaPorCFOP_DEBUG]
ALTER PROCEDURE [dbo].[usp_RS_NotasCompoemICMSSaidaPorCFOP]
	@empcod smallint,
	@Data_de date = null, 
	@Data_ate date = null,
	@NFSTIP varchar(10) = '', 
	@CFOP varchar(100) = '', 
	@NFSNUM int = 0, 
	@ECF varchar(5) = '', 
	@COO varchar(10) = '', 
	@CUPOM varchar(10) = '', 
	@CXA varchar(10) = ''	
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @dataDe date, @dataAte date,
			@empresaTemLoja bit, @DataModificacaoST datetime;

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;	
	SET @dataDe = @Data_de
	SET @dataAte = @Data_ate	

-- Atribuicoes internas	
	SET @DataModificacaoST = CONVERT(DATE, GETDATE()) -- Quando for colocado em vigor a altera��o no ST, preciso colocar aqui a data do dia anterior a mudan�a	
	SET @empresaTemLoja = dbo.ufn_Get_TemFrenteLoja(@codigoEmpresa)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF OBJECT_ID('tempdb.dbo.#CFOP1') IS NOT NULL
		DROP TABLE #CFOP1;
 
	DECLARE @sql varchar (500)
 
	IF @CFOP <> ''
	BEGIN 
	set @sql = '	
					SELECT 
					DISTINCT NFSCFOP AS CFOP
				
					INTO #CFOP2
					FROM TBS0671 (NOLOCK)
						
					UNION 
							
					SELECT DISTINCT NFDCFOP AS CFOP
					FROM TBS1172 (NOLOCK)
						
					UNION 
							
					SELECT DISTINCT NDFCFOP AS CFOP
					FROM TBS1431 (NOLOCK)
						
					UNION 
							
					SELECT TOP 1 CONVERT(CHAR(6),''5.929C'') AS CFOP
					FROM TBS001 (NOLOCK)

							
				SELECT CFOP FROM #CFOP2 WHERE CFOP IN ('''+replace(rtrim(@CFOP),',',''',''')+''') '
	END

	IF @CFOP = ''
	BEGIN 
	set @sql = '	SELECT 
					DISTINCT NFSCFOP AS CFOP
				
					FROM TBS0671 (NOLOCK)
						
					UNION 
							
					SELECT DISTINCT NFDCFOP AS CFOP
					FROM TBS1172 (NOLOCK)
							
					UNION 
							
					SELECT DISTINCT NDFCFOP AS CFOP
					FROM TBS1431 (NOLOCK)
				
					UNION 
							
					SELECT TOP 1 CONVERT(CHAR(6),''5.929C'') AS CFOP
					FROM TBS001
						'
	END


	CREATE TABLE #CFOP1 (CFOP CHAR (6))
	INSERT INTO #CFOP1
	EXEC(@sql)

--	select * from #CFOP1

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- @NFSTIP

	IF OBJECT_ID('tempdb.dbo.#NFSTIP') IS NOT NULL
		DROP TABLE #NFSTIP;
 
	-- DECLARE @sql varchar (500)
 
	IF @NFSTIP <> ''
	BEGIN 
	set @sql = '	
					SELECT 
					DISTINCT NFSTIP
				
					FROM TBS067 (NOLOCK)
					WHERE NFSTIP IN ('''+replace(UPPER(RTRIM(@NFSTIP)),',',''',''')+''')
						
					UNION 
							
					SELECT TOP 1 ''D''
					FROM TBS117 (NOLOCK)
					WHERE ''D'' IN ('''+replace(UPPER(RTRIM(@NFSTIP)),',',''',''')+''')

					UNION 
							
					SELECT TOP 1 ''D''
					FROM TBS143 (NOLOCK)
					WHERE ''D'' IN ('''+replace(UPPER(RTRIM(@NFSTIP)),',',''',''')+''')
				
					UNION
				
					SELECT TOP 1 ''F''
					FROM TBS010 (NOLOCK)
					WHERE ''F'' IN ('''+replace(UPPER(RTRIM(@NFSTIP)),',',''',''')+''')
				'
	END

	IF @NFSTIP = ''
	BEGIN 
	set @sql = '	SELECT 
					DISTINCT NFSTIP
				
					FROM TBS067 (NOLOCK)
						
					UNION 
							
					SELECT ''D''
				
					UNION 
				
					SELECT ''F''
						'
	END


	CREATE TABLE #NFSTIP (NFSTIP CHAR (1))
	INSERT INTO #NFSTIP
	EXEC(@sql)

--	select * from #NFSTIP;
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- ESSES CFOP NAO PODEM APARECER NO RELATORIO DE ICMS

	IF OBJECT_ID('tempdb.dbo.#CFOP') IS NOT NULL
		DROP TABLE #CFOP;
	
	CREATE TABLE #CFOP (TIPO CHAR (1), CFOP CHAR(5))

	-- SAIDAS '5.922','6.922'
	INSERT INTO #CFOP VALUES ('S','5.922')
	INSERT INTO #CFOP VALUES ('S','6.922')
	INSERT INTO #CFOP VALUES ('S','5.556')
	INSERT INTO #CFOP VALUES ('S','5.557')
	INSERT INTO #CFOP VALUES ('S','6.556')
	INSERT INTO #CFOP VALUES ('S','6.557')

----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TBS080 TABELA DE AUTORIZA��O

	IF OBJECT_ID('tempdb.dbo.#TBS080') IS NOT NULL
		DROP TABLE #TBS080;	
	
	SELECT 
		ENFNUM,
		SNEEMPCOD,
		SNESER,
		ENFTIPDOC,
		ENFFINEMI,
		ENFCODDES,
		ENFCNPJCPF,
		ENFCHAACE

	INTO #TBS080 FROM TBS080 (NOLOCK)

	WHERE 
		ENFDATEMI BETWEEN @dataDe AND @dataAte AND
		ENFSIT = 6 AND
		ENFTIPDOC = 1

 --SELECT * FROM #TBS080 (NOLOCK) 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- VENDAS OU COMPLEMENTO DE ICMS

	IF OBJECT_ID('tempdb.dbo.#NFS') IS NOT NULL
		DROP TABLE #NFS;

	SELECT 
		1 AS ITENS,
		CASE WHEN B.NFSDESICMS = 'S' AND A.NFSEFS = 'N'
			THEN SUBSTRING(A.NFSCST,1,1) + '40'
			ELSE A.NFSCST
		END AS CST,
		B.UFESIG		AS UF,
		A.NFSCFOP		AS CFOP,
		A.NFSNUM 		AS NF, 
		B.NFSDATEMI		AS DAT,
		dbo.NFSTOTPRO(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)	AS NFSTOTPRO,

		dbo.NFSTOTITE(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE) + 						-- valor do item + st antigo ou st novo
		CASE WHEN B.NFSDATEMI <= @DataModificacaoST
			THEN dbo.NFSVALICMSST_Antigo(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)		-- VALOR ICMS ST ANTIGO
			ELSE dbo.NFSVALICMSSTRET(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)			-- VALOR ICMS ST FORMULA NOVA
		END	AS NFSTOTITEST, 		-- TOTAL DA NOTA

		CASE WHEN A.NFSCFOP COLLATE DATABASE_DEFAULT NOT IN (SELECT CFOP FROM #CFOP WHERE TIPO = 'S') AND B.NFSDESICMS <> 'S'
			THEN 
				CASE WHEN B.NFSTIP = 'N'
					THEN dbo.NFSBASICMS(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)
					ELSE NFSBASICMSCOM
				END	
			ELSE 0
		END AS NFSBASICMS, 			-- BASE ICMS

		CASE WHEN A.NFSCFOP COLLATE DATABASE_DEFAULT NOT IN (SELECT CFOP FROM #CFOP WHERE TIPO = 'S') AND B.NFSDESICMS <> 'S'
			THEN 
				CASE WHEN B.NFSTIP = 'N'
					THEN dbo.NFSVALICMS(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)
					ELSE NFSBASICMSCOM * NFSPERICMS / 100
				END
			ELSE 0
		END AS NFSVALICMS, 			-- VALOR ICMS 

		CASE WHEN B.NFSTIP = 'N'
			THEN dbo.NFSBASICMSST(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)			-- VALOR ICMS ST
			ELSE NFSBASICMSSTCOM 
		END AS NFSBASICMSST,

		CASE WHEN B.NFSTIP = 'N'
			THEN 
				CASE WHEN B.NFSDATEMI <= @DataModificacaoST
					THEN dbo.NFSVALICMSST_Antigo(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)		-- VALOR ICMS ST ANTIGO
					ELSE dbo.NFSVALICMSSTRET(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)			-- VALOR ICMS ST FORMULA NOVA
				END
			ELSE NFSBASICMSSTCOM * NFSPERICMSST / 100
		END AS NFSVALICMSST,

		CASE WHEN B.NFSDESICMS = 'S'
			THEN 0
			ELSE 
				CASE WHEN SUBSTRING(A.NFSCFOP,3,3) = '922' 
					THEN dbo.NFSBASICMS(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)
					ELSE 0
				END
		END AS NFSBASICMSFUT,	-- BASE ICMS PARA ENTREGA FUTURA

		CASE WHEN B.NFSDESICMS = 'S'
			THEN 0
			ELSE 
				CASE WHEN SUBSTRING(A.NFSCFOP,3,3) = '922' 
					THEN dbo.NFSVALICMS(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)
					ELSE 0
				END
		END AS NFSVALICMSFUT,	-- VALOR ICMS PARA ENTREGA FUTURA

		CASE WHEN SUBSTRING(NFSCST,2,2) IN ('30','40') or (B.NFSDESICMS = 'S' AND A.NFSEFS = 'N')
			THEN 
				CASE WHEN B.NFSTIP = 'N' 
					THEN dbo.NFSTOTITE(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE) + 						-- valor do item + st antigo ou st novo
						CASE WHEN B.NFSDATEMI <= @DataModificacaoST
							THEN dbo.NFSVALICMSST_Antigo(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)		-- VALOR ICMS ST ANTIGO
							ELSE dbo.NFSVALICMSSTRET(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)			-- VALOR ICMS ST FORMULA NOVA
						END	-- TOTAL DA NOTA
					ELSE NFSTOTITECOM + (ROUND(NFSBASICMSSTCOM * NFSPERICMSST / 100,2))
				END 
			ELSE 0
		END AS ICMSISENTO ,																		-- AS VALOR ICMS ISENTO/

		CASE WHEN B.NFSDESICMS = 'S' AND A.NFSEFS = 'N'
			THEN 0
			ELSE 
				CASE WHEN SUBSTRING(NFSCST,2,2) IN ('41','50') 
					THEN 
						CASE WHEN B.NFSTIP = 'N' 
							THEN dbo.NFSTOTITE(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE) + 						-- valor do item + st antigo ou st novo
								CASE WHEN B.NFSDATEMI <= @DataModificacaoST
									THEN dbo.NFSVALICMSST_Antigo(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)		-- VALOR ICMS ST ANTIGO
									ELSE dbo.NFSVALICMSSTRET(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)			-- VALOR ICMS ST FORMULA NOVA
								END	-- TOTAL DA NOTA
							ELSE NFSTOTITECOM + (ROUND(NFSBASICMSSTCOM * NFSPERICMSST / 100,2))
						END 
					ELSE 0
				END
		END AS ICMSNAOTRI ,																		-- ICMS N�O TRIBUTADO

		CASE WHEN B.NFSDESICMS = 'S' AND A.NFSEFS = 'N'
			THEN 0
			ELSE 
				CASE WHEN SUBSTRING(NFSCST,2,2) IN ('60')
					THEN 
						CASE WHEN B.NFSTIP = 'N' 
							THEN dbo.NFSTOTITE(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE) + 						-- valor do item + st antigo ou st novo
								CASE WHEN B.NFSDATEMI <= @DataModificacaoST
									THEN dbo.NFSVALICMSST_Antigo(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)		-- VALOR ICMS ST ANTIGO
									ELSE dbo.NFSVALICMSSTRET(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE)			-- VALOR ICMS ST FORMULA NOVA
								END	-- TOTAL DA NOTA
							ELSE NFSTOTITECOM + (ROUND(NFSBASICMSSTCOM * NFSPERICMSST / 100,2))
						END 
					ELSE 0
				END 
		END AS ICMSTRIANT,																		-- ICMS TRIBUTADO ANTERIORMENTE
		D.ENFCHAACE,
		dbo.NFSVDDITE(A.NFSEMPCOD, A.NFSNUM, A.SNEEMPCOD, A.SNESER, A.NFSITE) AS NFSVDDITE -- ADICIONADO DIA 31/01/2019
	INTO #NFS FROM  TBS0671 A (NOLOCK)	
		INNER JOIN TBS067 B (NOLOCK) ON A.NFSEMPCOD = B.NFSEMPCOD AND A.NFSNUM = B.NFSNUM AND A.SNEEMPCOD = B.SNEEMPCOD AND A.SNESER = B.SNESER
		INNER JOIN #TBS080 D (NOLOCK) ON A.NFSNUM = D.ENFNUM AND A.SNEEMPCOD = D.SNEEMPCOD AND A.SNESER = D.SNESER 

	WHERE
		B.NFSDATEMI BETWEEN @dataDe AND @dataAte AND
		NFSTIP IN('N','C') AND
		D.ENFFINEMI <> 4 AND 
		B.NFSTIP COLLATE DATABASE_DEFAULT IN (SELECT * FROM #NFSTIP)

-- select * from #NFS

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CRIANDO TABELA DE DEVOLU��O

	IF OBJECT_ID('tempdb.dbo.#NFD') IS NOT NULL
		DROP TABLE #NFD;	

	SELECT 
		1 AS ITENS,
		A.NFDCSTCSOSN AS CST,
		B.NFDESTDES AS UF,
		A.NFDCFOP AS CFOP,
		A.NFDNUM AS NF,
		B.NFDDATEMI AS DAT, 

		NFDQTD * NFDPRE	AS NFSTOTPRO,

		(NFDQTD * NFDPRE) - NFDVALDES + NFDVALFRE + NFDVALSEG + NFDVALOUTDES + NFDVALIPI + NFDVALICMSST AS NFSTOTITEST, 	  -- TOTAL DA NOTA

		CASE WHEN A.NFDCFOP COLLATE DATABASE_DEFAULT NOT IN (SELECT CFOP FROM #CFOP WHERE TIPO = 'S')
			THEN A.NFDBASICMS
			ELSE 0
		END AS NFSBASICMS, 		-- BASE ICMS
		CASE WHEN A.NFDCFOP COLLATE DATABASE_DEFAULT NOT IN (SELECT CFOP FROM #CFOP WHERE TIPO = 'S')
			THEN A.NFDVALICMS
			ELSE 0
		END AS NFSVALICMS,  		-- VALOR ICMS

		--0 AS NFSBASICMSST, -- BASE ICMS ST

		--0 AS NFSVALICMSST, -- VALOR ICMS ST

		--CASE WHEN SUBSTRING(A.NFDCFOP,3,3) = '922' 
		--	THEN A.NFDBASICMS
		--	ELSE 0
		--END AS NFSBASICMSFUT,	-- BASE ICMS PARA ENTREGA FUTURA
		--
		--CASE WHEN SUBSTRING(A.NFDCFOP,3,3) = '922' 
		--	THEN A.NFDVALICMS
		--	ELSE 0
		--END AS NFSVALICMSFUT,	-- VALOR ICMS PARA ENTREGA FUTURA


		CASE WHEN SUBSTRING(NFDCSTCSOSN,2,2) IN ('30','40')
			THEN (NFDQTD * NFDPRE) - NFDVALDES + NFDVALFRE + NFDVALSEG + NFDVALOUTDES + NFDVALIPI + NFDVALICMSST  	  -- TOTAL DA NOTA
			ELSE 0
		END AS ICMSISENTO, 		-- AS VALOR ICMS ISENTO

		CASE WHEN SUBSTRING(NFDCSTCSOSN,2,2) IN ('41','50')
			THEN (NFDQTD * NFDPRE) - NFDVALDES + NFDVALFRE + NFDVALSEG + NFDVALOUTDES + NFDVALIPI + NFDVALICMSST  	  -- TOTAL DA NOTA
			ELSE 0
		END AS ICMSNAOTRI, 		-- AS VALOR ICMS NAO TRIBUTADO

		CASE WHEN SUBSTRING(NFDCSTCSOSN,2,2) IN ('60')
			THEN (NFDQTD * NFDPRE) - NFDVALDES + NFDVALFRE + NFDVALSEG + NFDVALOUTDES + NFDVALIPI + NFDVALICMSST  	  -- TOTAL DA NOTA
			ELSE 0
		END AS ICMSTRIANT,		-- ICMS TRIBUTADO ANTERIORMENTE
		D.ENFCHAACE,
		NFDVALDES AS NFSVDDITE -- ADICIONADO DIA 31/01/2019 

	INTO #NFD FROM TBS1172 A (NOLOCK)
		INNER JOIN TBS117 B (NOLOCK) ON A.NFDEMPCOD = B.NFDEMPCOD AND A.NFDNUM = B.NFDNUM AND A.SNEEMPCOD = B.SNEEMPCOD AND A.SNESER = B.SNESER
		INNER JOIN #TBS080 D (NOLOCK) ON A.NFDNUM = D.ENFNUM AND A.SNEEMPCOD = D.SNEEMPCOD AND A.SNESER = D.SNESER

	WHERE
		B.NFDDATEMI BETWEEN @dataDe AND @dataAte AND
		D.ENFFINEMI = 4 AND
		'D' COLLATE DATABASE_DEFAULT IN (SELECT * FROM #NFSTIP)

--	SELECT * from #NFD;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CRIANDO TABELA DE DEVOLU��O - NOVA - TBS143 - 08/01/2024

	IF OBJECT_ID('tempdb.dbo.#NFD_NOVA') IS NOT NULL	
		DROP TABLE #NFD_NOVA;	

	SELECT 
		1 AS ITENS,
		A.NDFCSTCSOSN AS CST,
		B.NDFESTDES AS UF,
		A.NDFCFOP AS CFOP,
		B.NDFENFNUM AS NF,
		B.NDFDATEMI AS DAT, 

		NDFQTD * NDFPRE	AS NFSTOTPRO,

		(NDFQTD * NDFPRE) - NDFVALDESITE + NDFVALFREITE + NDFVALSEGITE + NDFVALOUTDESITE + NDFVALIPI + NDFVALICMSST AS NFSTOTITEST, 	  -- TOTAL DA NOTA

		CASE WHEN A.NDFCFOP COLLATE DATABASE_DEFAULT NOT IN (SELECT CFOP FROM #CFOP WHERE TIPO = 'S')
			THEN A.NDFBASICMS
			ELSE 0
		END AS NFSBASICMS, 		-- BASE ICMS
		CASE WHEN A.NDFCFOP COLLATE DATABASE_DEFAULT NOT IN (SELECT CFOP FROM #CFOP WHERE TIPO = 'S')
			THEN A.NDFVALICMS
			ELSE 0
		END AS NFSVALICMS,  		-- VALOR ICMS

		CASE WHEN SUBSTRING(NDFCSTCSOSN,2,2) IN ('30','40')
			THEN (NDFQTD * NDFPRE) - NDFVALDESITE + NDFVALFREITE + NDFVALSEGITE + NDFVALOUTDESITE + NDFVALIPI + NDFVALICMSST  	  -- TOTAL DA NOTA
			ELSE 0
		END AS ICMSISENTO, 		-- AS VALOR ICMS ISENTO

		CASE WHEN SUBSTRING(NDFCSTCSOSN,2,2) IN ('41','50')
			THEN (NDFQTD * NDFPRE) - NDFVALDESITE + NDFVALFREITE + NDFVALSEGITE + NDFVALOUTDESITE + NDFVALIPI + NDFVALICMSST  	  -- TOTAL DA NOTA
			ELSE 0
		END AS ICMSNAOTRI, 		-- AS VALOR ICMS NAO TRIBUTADO

		CASE WHEN SUBSTRING(NDFCSTCSOSN,2,2) IN ('60')
			THEN (NDFQTD * NDFPRE) - NDFVALDESITE + NDFVALFREITE + NDFVALSEGITE + NDFVALOUTDESITE + NDFVALIPI + NDFVALICMSST  	  -- TOTAL DA NOTA
			ELSE 0
		END AS ICMSTRIANT,		-- ICMS TRIBUTADO ANTERIORMENTE
		D.ENFCHAACE,
		NDFVALDESITE AS NFSVDDITE -- ADICIONADO DIA 31/01/2019 

	INTO #NFD_NOVA FROM	TBS1431 A (NOLOCK)
		INNER JOIN TBS143 B (NOLOCK) ON A.NDFEMPCOD = B.NDFEMPCOD AND A.NDFNUMDOC = B.NDFNUMDOC
		INNER JOIN #TBS080 D (NOLOCK) ON NDFENFNUM = ENFNUM and SNESER = NDFSNESER

	WHERE
		B.NDFDATEMI BETWEEN @dataDe AND @dataAte AND
		D.ENFFINEMI = 4 AND
		'D' COLLATE DATABASE_DEFAULT IN (SELECT * FROM #NFSTIP)

--	SELECT * from #NFD_NOVA;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Obtem os registros dos cupons da tabela movcaixagz, via SP que gera a tabela global ##MOVCAIXAGZ

	EXEC usp_Get_Vendas_MovCaixaGZ 
    	@pdataDe = @Data_De, 
    	@pdataAte = @Data_Ate,    
    	@pStatus = '01',
		@pCancelados = 'N'

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	

	IF OBJECT_ID('tempdb.dbo.#TMP') IS NOT NULL
		DROP TABLE #TMP;
   
	SELECT 
		nfce_chave AS M2_CHAVE,
		data AS M2_DAT,
		agencia AS M2_CFOP,	
		tributacao AS M2_TRI,
		banco AS M2_CST,  -- M2_CST,
		item AS M2_ITE,
		loja AS M2_LOJ, 
		cupom AS M2_CUP, 
		0 AS M2_COO, 
		0 AS M2_ECF, 
		caixa AS M2_CXA,
		cdprod AS M2_PROCOD,
		valortot AS M2_VALBRU,
		valorliq AS M2_LIQUIDO,
		desccupom AS M2_DESCUP
	INTO #TMP FROM ##MOVCAIXAGZ

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Apaga tabela global temporaria, sem uso a partir desse ponto
	DROP TABLE ##MOVCAIXAGZ	

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CRIANDO TABELA DE ITENS COM OS TRIBUTOS NECESSARIOS
	-- COLOQUEI O VALOR BRUTO COMO TOTAL DA NOTA, PORQUE SE NAO O VALOR DA NOTA FICA MENOR QUE A BASE DO ICMS, E VALOR DO ICMS E O BRUTO/TRIBUTACAO 06/03/2018
	-- E O VALOR E BASE DE ICMS E REALIZADO NA HORA QUE PASSA O ITEM, E NO FINAL QUE DA O DESCONTO, OU SEJA, BASE E VALOR DE ICMS TEM QUE SER O BRUTO 06/03
	-- APOS VERIFICACAO NA IMPRESSORA FISCAL 28/03/2018 (RONALDO E CRISTIANO), FICOU DEFINIDO QUE A BASE DOS IMPOSTOS SERA O VALOR LIQUIDO

	IF OBJECT_ID('tempdb.dbo.#LIQUIDO') IS NOT NULL
		DROP TABLE #LIQUIDO;

	SELECT
		M2_CHAVE,
		M2_CXA,
		M2_CUP, 
		M2_COO, 
		M2_ECF,
		substring(M2_CHAVE, 32, 6) as M2_EXT, -- Adicionado dia 12/04/2021 
		M2_DAT AS DAT,
		'F' AS TIPO,
		1 AS ITENS,
		'SP' AS UF,
		C.M2_CST AS CST,
		C.M2_CFOP AS CFOP ,
		C.M2_VALBRU AS NFSTOTPRO ,		-- AQUI EH BASE DO ICMS PORQUE O DESCONTO VAI NO FINAL DO CUPOM
		C.M2_LIQUIDO AS NFSTOTITEST,	-- TOTAL DAS NOTAS, NO CASO DOS CUPONS NAO TEM NOTA , MAS COLQUEI LQUIDO, AGORA EH O BRUTO, VOLTOU PARA O LIQUIDO
		CASE WHEN C.M2_TRI / 100 > 0 
			THEN C.M2_LIQUIDO													
			ELSE 0 
		END AS NFSBASICMS, 							-- BASE ICMS
					
		C.M2_LIQUIDO * C.M2_TRI / 100 AS NFSVALICMS , -- VALOR LIQUIDO * PORCENTAGEM TRIBUTADA -- VALOR ICMS		

		CASE WHEN SUBSTRING(M2_CST,2,2) IN ('30','40')
			THEN C.M2_LIQUIDO
			ELSE 0
		END AS ICMSISENTO,							-- AS VALOR ICMS ISENTO
				
		CASE WHEN SUBSTRING(M2_CST,2,2) IN ('41','50')
			THEN C.M2_LIQUIDO
			ELSE 0
		END AS ICMSNAOTRI,					   -- AS VALOR ICMS NAO TRIBUTADO

		CASE WHEN SUBSTRING(M2_CST,2,2) IN ('60')
			THEN C.M2_LIQUIDO
			ELSE 0
		END AS ICMSTRIANT,					   -- AS VALOR ICMS NAO TRIBUTADO
		C.M2_DESCUP AS NFSVDDITE -- ADICIONADO DIA 31/01/2019  
			
	INTO #LIQUIDO FROM #TMP C 
		LEFT JOIN TBS010 B (NOLOCK) ON C.M2_PROCOD = CONVERT(decimal(15,0),B.PROCOD)

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TIVE QUE UNIR AS TABELAS DE NFS/COMPL COM OS CUPONS DESSA FORMA PORQUE SE N�O , N�O FUNCIONA NO REPORT SERVER

	IF OBJECT_ID('tempdb.dbo.#NFSCUP') IS NOT NULL
		DROP TABLE #NFSCUP;

	SELECT 
		'N' AS TIPO,
		CFOP,
		DAT AS NFSDATEMI,
		NF AS NFSNUM,
		0 AS CXA,
		0 AS ECF,
		0 AS COO,
		0 AS CUPOM,
		0 as EXTRATO,
		SUM(A.ITENS) AS ITENS,
		ROUND(SUM(A.NFSTOTPRO),2)			AS NFSTOTPRO, 		-- TOTAL DOS PRODUTOS
		ROUND(SUM(A.NFSTOTITEST),2)			AS NFSTOTITEST, 	-- TOTAL DA NOTA
		ROUND(SUM(A.NFSBASICMS),2)			AS NFSBASICMS, 		-- BASE ICMS
		ROUND(SUM(A.NFSVALICMS),2)			AS NFSVALICMS, 		-- VALOR ICMS
		ROUND(SUM(A.NFSBASICMSST),2)		AS NFSBASICMSST, 	-- BASE ICMS ST
		ROUND(SUM(A.NFSVALICMSST),2)		AS NFSVALICMSST, 	-- VALOR ICMS ST
		ROUND(SUM(A.NFSBASICMSFUT),2)		AS NFSBASICMSFUT, 	-- BASE ICMS FUTURO
		ROUND(SUM(A.NFSVALICMSFUT),2)		AS NFSVALICMSFUT, 	-- VALOR ICMS FUTURO
		ROUND(SUM(A.ICMSISENTO),2)			AS ICMSISENTO,	 	-- AS VALOR ICMS ISENTO
		ROUND(SUM(A.ICMSNAOTRI),2)			AS ICMSNAOTRI,	 	-- AS VALOR ICMS N�O TRIBUTADO
		ROUND(SUM(A.ICMSTRIANT),2)			AS ICMSTRIANT,		-- AS VALOR ICMS TRIBUTADO ANTERIORMENTE
		ROUND(SUM(A.NFSTOTITEST - A.NFSBASICMS - A.ICMSISENTO - A.ICMSNAOTRI),2)	AS ICMSOUTROS,
		ENFCHAACE,
		ROUND(SUM(A.NFSVDDITE),2) AS NFSVDDITE -- ADICIONADO DIA 31/01/2019  

	INTO #NFSCUP FROM #NFS A

	WHERE 
		CFOP COLLATE DATABASE_DEFAULT IN ((SELECT CFOP FROM #CFOP1)) AND
		0 = CASE WHEN @COO = '' THEN 0 ELSE RTRIM(LTRIM(@COO)) END AND
		0 = CASE WHEN @CUPOM = '' THEN 0 ELSE RTRIM(LTRIM(@CUPOM)) END AND 
		0 = CASE WHEN @ECF = '' THEN 0 ELSE RTRIM(LTRIM(@ECF)) END AND 
		0 = CASE WHEN @CXA = '' THEN 0 ELSE RTRIM(LTRIM(@CXA)) END 

	GROUP BY
		CFOP,
		DAT,
		NF,
		ENFCHAACE

	UNION 
	SELECT 
		TIPO,
		CFOP COLLATE DATABASE_DEFAULT,
		DAT AS NFSDATEMI,
		0 AS NFSNUM,
		M2_CXA AS CXA,
		M2_ECF AS ECF,
		M2_COO AS COO,
		M2_CUP AS CUPOM,
		M2_EXT as EXTRATO, 
		SUM(A.ITENS) AS ITENS,
		ROUND(SUM(A.NFSTOTPRO),2)			AS NFSTOTPRO, 		-- TOTAL DOS PRODUTOS
		ROUND(SUM(A.NFSTOTITEST),2)			AS NFSTOTITEST, 	-- TOTAL DA NOTA, AGORA DOS PRODUTOS 06/03/2018, VOLTOU PARA O LIQUIDO 28/03/2018
		ROUND(SUM(A.NFSBASICMS),2)			AS NFSBASICMS, 		-- BASE ICMS
		ROUND(SUM(A.NFSVALICMS),2)			AS NFSVALICMS, 		-- VALOR ICMS
		0									AS NFSBASICMSST, 	-- BASE ICMS ST
		0									AS NFSVALICMSST, 	-- VALOR ICMS ST
		0									AS NFSBASICMSFUT, 	-- BASE ICMS FUTURO
		0									AS NFSVALICMSFUT, 	-- VALOR ICMS FUTURO
		ROUND(SUM(A.ICMSISENTO),2)			AS ICMSISENTO,	 	-- AS VALOR ICMS ISENTO
		ROUND(SUM(A.ICMSNAOTRI),2)			AS ICMSNAOTRI,	 	-- AS VALOR ICMS N�O TRIBUTADO
		ROUND(SUM(A.ICMSTRIANT),2)			AS ICMSTRIANT,		-- AS VALOR ICMS TRIBUTADO ANTERIORMENTE
		ROUND(SUM(A.NFSTOTITEST - A.NFSBASICMS - A.ICMSISENTO - A.ICMSNAOTRI),2)	AS ICMSOUTROS,
		M2_CHAVE COLLATE DATABASE_DEFAULT,
		ROUND(SUM(A.NFSVDDITE),2) AS NFSVDDITE -- ADICIONADO DIA 31/01/2019  
					
	FROM #LIQUIDO A

	WHERE
		CFOP COLLATE DATABASE_DEFAULT IN ((SELECT CFOP FROM #CFOP1)) AND
		M2_COO = CASE WHEN @COO = '' THEN M2_COO ELSE RTRIM(LTRIM(@COO)) END AND
		M2_CUP = CASE WHEN @CUPOM = '' THEN M2_CUP ELSE RTRIM(LTRIM(@CUPOM)) END AND 
		M2_ECF = CASE WHEN @ECF = '' THEN M2_ECF ELSE RTRIM(LTRIM(@ECF)) END AND
		M2_CXA = CASE WHEN @CXA = '' THEN M2_CXA ELSE RTRIM(LTRIM(@CXA)) END AND
		TIPO COLLATE DATABASE_DEFAULT IN (SELECT * FROM #NFSTIP)

	GROUP BY
		TIPO,
		CFOP,
		DAT ,
		M2_CXA,
		M2_ECF ,
		M2_COO,
		M2_CUP,
		M2_CHAVE,
		M2_EXT

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	SELECT 
		CFOP,
		NFSDATEMI,
		NFSNUM,
		CXA,
		ECF,
		COO,
		CUPOM,
		EXTRATO,
		SUM(A.ITENS) AS ITENS,
		ROUND(SUM(A.NFSTOTPRO),2)			AS NFSTOTPRO, 		-- TOTAL DOS PRODUTOS
		ROUND(SUM(A.NFSTOTITEST),2)			AS NFSTOTITEST, 	-- TOTAL DA NOTA
		ROUND(SUM(A.NFSBASICMS),2)			AS NFSBASICMS, 		-- BASE ICMS
		ROUND(SUM(A.NFSVALICMS),2)			AS NFSVALICMS, 		-- VALOR ICMS
		ROUND(SUM(A.NFSBASICMSST),2)		AS NFSBASICMSST, 	-- BASE ICMS ST
		ROUND(SUM(A.NFSVALICMSST),2)		AS NFSVALICMSST, 	-- VALOR ICMS ST
		ROUND(SUM(A.NFSBASICMSFUT),2)		AS NFSBASICMSFUT, 	-- BASE ICMS FUTURO
		ROUND(SUM(A.NFSVALICMSFUT),2)		AS NFSVALICMSFUT, 	-- VALOR ICMS FUTURO
		ROUND(SUM(A.ICMSISENTO),2)			AS ICMSISENTO,	 	-- AS VALOR ICMS ISENTO
		ROUND(SUM(A.ICMSNAOTRI),2)			AS ICMSNAOTRI,	 	-- AS VALOR ICMS N�O TRIBUTADO
		ROUND(SUM(A.ICMSTRIANT),2)			AS ICMSTRIANT,		-- AS VALOR ICMS TRIBUTADO ANTERIORMENTE
		ROUND(SUM(ICMSOUTROS),2)			AS ICMSOUTROS,
		0 AS IPI,
		ENFCHAACE,
		ROUND(SUM(A.NFSVDDITE),2) AS NFSVDDITE -- ADICIONADO DIA 31/01/2019  

	FROM #NFSCUP A

	GROUP BY
		CFOP,
		NFSDATEMI,
		NFSNUM,
		CXA,
		ECF,
		COO,
		CUPOM,
		ENFCHAACE,
		EXTRATO

	UNION
	SELECT 
		CFOP,
		DAT,
		NF,
		0,
		0,
		0,
		0,
		0,
		SUM(A.ITENS) AS ITENS,
		ROUND(SUM(A.NFSTOTPRO),2)			AS NFSTOTPRO, 		-- TOTAL DOS PRODUTOS
		ROUND(SUM(A.NFSTOTITEST),2)			AS NFSTOTITEST, 	-- TOTAL DA NOTA
		ROUND(SUM(A.NFSBASICMS),2)			AS NFSBASICMS, 		-- BASE ICMS
		ROUND(SUM(A.NFSVALICMS),2)			AS NFSVALICMS, 		-- VALOR ICMS
		0									AS NFSBASICMSST,
		0									AS NFSVALICMSST,
		0									AS NFSBASICMSFUT,
		0                         			AS NFSVALICMSFUT,
		ROUND(SUM(A.ICMSISENTO),2)			AS ICMSISENTO,	 	-- AS VALOR ICMS ISENTO
		ROUND(SUM(A.ICMSNAOTRI),2)			AS ICMSNAOTRI,	 	-- AS VALOR ICMS N�O TRIBUTADO
		ROUND(SUM(A.ICMSTRIANT),2)			AS ICMSTRIANT,		-- AS VALOR ICMS TRIBUTADO ANTERIORMENTE
		ROUND(SUM(A.NFSTOTITEST - A.NFSBASICMS - A.ICMSISENTO - A.ICMSNAOTRI),2)	AS ICMSOUTROS,
		0 AS IPI,
		ENFCHAACE COLLATE DATABASE_DEFAULT,
		ROUND(SUM(A.NFSVDDITE),2) AS NFSVDDITE -- ADICIONADO DIA 31/01/2019  

	FROM #NFD A

	WHERE
		CFOP COLLATE DATABASE_DEFAULT IN ((SELECT CFOP FROM #CFOP1)) AND
		0 = CASE WHEN @COO = '' THEN 0 ELSE RTRIM(LTRIM(@COO)) END AND
		0 = CASE WHEN @CUPOM = '' THEN 0 ELSE RTRIM(LTRIM(@CUPOM)) END AND 
		0 = CASE WHEN @ECF = '' THEN 0 ELSE RTRIM(LTRIM(@ECF)) END AND
		0 = CASE WHEN @CXA = '' THEN 0 ELSE RTRIM(LTRIM(@CXA)) END 

	GROUP BY 
		CFOP,
		DAT,
		NF,
		ENFCHAACE

	-- UNION com a nota tabela TBS143 de devolucao a fornecedor
	UNION 
	SELECT
		CFOP,
		DAT,
		NF,
		0,
		0,
		0,
		0,
		0,
		SUM(A.ITENS) AS ITENS,
		ROUND(SUM(A.NFSTOTPRO),2)			AS NFSTOTPRO, 		-- TOTAL DOS PRODUTOS
		ROUND(SUM(A.NFSTOTITEST),2)			AS NFSTOTITEST, 	-- TOTAL DA NOTA
		ROUND(SUM(A.NFSBASICMS),2)			AS NFSBASICMS, 		-- BASE ICMS
		ROUND(SUM(A.NFSVALICMS),2)			AS NFSVALICMS, 		-- VALOR ICMS
		0									AS NFSBASICMSST,
		0									AS NFSVALICMSST,
		0									AS NFSBASICMSFUT,
		0                         			AS NFSVALICMSFUT,
		ROUND(SUM(A.ICMSISENTO),2)			AS ICMSISENTO,	 	-- AS VALOR ICMS ISENTO
		ROUND(SUM(A.ICMSNAOTRI),2)			AS ICMSNAOTRI,	 	-- AS VALOR ICMS N�O TRIBUTADO
		ROUND(SUM(A.ICMSTRIANT),2)			AS ICMSTRIANT,		-- AS VALOR ICMS TRIBUTADO ANTERIORMENTE
		ROUND(SUM(A.NFSTOTITEST - A.NFSBASICMS - A.ICMSISENTO - A.ICMSNAOTRI),2)	AS ICMSOUTROS,
		0 AS IPI,
		ENFCHAACE COLLATE DATABASE_DEFAULT,
		ROUND(SUM(A.NFSVDDITE),2) AS NFSVDDITE -- ADICIONADO DIA 31/01/2019  

	FROM #NFD_NOVA A

	WHERE
		CFOP COLLATE DATABASE_DEFAULT IN ((SELECT CFOP FROM #CFOP1)) AND
		0 = CASE WHEN @COO = '' THEN 0 ELSE RTRIM(LTRIM(@COO)) END AND
		0 = CASE WHEN @CUPOM = '' THEN 0 ELSE RTRIM(LTRIM(@CUPOM)) END AND 
		0 = CASE WHEN @ECF = '' THEN 0 ELSE RTRIM(LTRIM(@ECF)) END AND
		0 = CASE WHEN @CXA = '' THEN 0 ELSE RTRIM(LTRIM(@CXA)) END 

	GROUP BY 
		CFOP,
		DAT,
		NF,
		ENFCHAACE

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
END