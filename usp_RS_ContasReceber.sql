/*
====================================================================================================================================================================================
WREL016 - Contas a Receber
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
28/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
19/02/2024 WILLIAM
	- Inclusão de filtro por "vendedor" diretamente no select na TBS056
17/02/2024 WILLIAM
	- Conversão para Stored procedure
	- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", SQL deixa de verificar SP no BD Master, buscando direto no SIBD
	- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas
	- Uso da função "fSplit" para transformar os filtros multi-valores em tabelas, para facilitar condições via cláusula "IN()"
====================================================================================================================================================================================
*/
ALTER PROC [dbo].[usp_RS_ContasReceber]
--CREATE PROC [dbo].[usp_RS_ContasReceber]
	@empcod smallint,
	@DataDeE datetime	= null,
	@DataAteE datetime	= null,
	@VencDe datetime	= null,
	@VencAte datetime	= null,
	@BaiDe datetime		= null,
	@BaiAte datetime	= null,
	@TituloDe int		= 0,
	@TituloAte int		= 0,
	@NomCli varchar(60)	= '',
	@Portador int		= null,
	@codcli int			= 0,
	@VENCOD int			= null,
	@VENNOM varchar(50)	= '',
	@PFXCOD varchar(500)= '',
	@Opcao varchar(500)	= '',
	@motbai varchar(500)= ''
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	DECLARE	@codigoEmpresa smallint, @empresaTBS002 smallint, @empresaTBS004 smallint, @empresaTBS056 smallint,
			@CREDATEMI_DE datetime, @CREDATEMI_ATE datetime, @CREDATVENREA_DE datetime, @CREDATVENREA_ATE datetime,	@CREDATBAI_DE datetime, @CREDATBAI_ATE datetime, 
			@CRETIT_DE int, @CRETIT_ATE int, @CLICOD int, @CRECLINOM varchar(60), @PORCOD int, @prefixos varchar(500), @Opcoes varchar(500),@Motivos varchar(500),
			@Query nvarchar (MAX), @ParmDef nvarchar (500);

	-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;			
	SET @CREDATEMI_DE = (SELECT ISNULL(@DataDeE, '17530101'))
	SET @CREDATEMI_ATE = (SELECT ISNULL(@DataAteE, dateadd(year, 10, getdate())))
	SET @CREDATVENREA_DE = (SELECT ISNULL(@VencDe, '17530101'))
	SET @CREDATVENREA_ATE = (SELECT ISNULL(@VencAte, dateadd(year, 10, getdate())))
	SET @CREDATBAI_DE = (SELECT ISNULL(@BaiDe, '17530101'))
	SET @CREDATBAI_ATE = (SELECT ISNULL(@BaiAte, dateadd(year, 10, getdate())) )
	SET @CRETIT_DE = @TituloDe
	SET @CRETIT_ATE = IIf(@TituloAte = 0, 999999, @TituloAte)
	SET @CLICOD = @codcli
	SET @CRECLINOM = @NomCli
	SET @PORCOD = @Portador	
	SET @prefixos = @PFXCOD
	SET @Opcoes = @Opcao
	SET @Motivos = @motbai

-- Quebra os filtros Multi-valores em tabelas via função "Split", para facilitar a cláusula "IN()"
	If object_id('TempDB.dbo.#PREFIXOS') is not null
		DROP TABLE #PREFIXOS;
	If object_id('TempDB.dbo.#OPCOES') is not null
		DROP TABLE #OPCOES;
	If object_id('TempDB.dbo.#MOTIVOS') is not null
		DROP TABLE #MOTIVOS;

    SELECT
		elemento as valor
	INTO #PREFIXOS FROM fSplit(@prefixos, ',')
    SELECT
		elemento as valor
	INTO #OPCOES FROM fSplit(@Opcoes, ',')
    SELECT
		elemento as valor
	INTO #MOTIVOS FROM fSplit(@Motivos, ',')

-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS004', @empresaTBS004 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS056', @empresaTBS056 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- filtra vendedor

	IF OBJECT_ID('tempdb.dbo.#TBS004') IS NOT NULL	
		DROP TABLE #TBS004;

	SELECT 
		VENEMPCOD,
		VENCOD,
		RTRIM(LTRIM(VENNOM)) AS VENNOM
	INTO #TBS004 FROM TBS004 (NOLOCK)

	WHERE 
		VENEMPCOD = @empresaTBS004 AND
		VENCOD = CASE WHEN @VENCOD IS NULL THEN VENCOD ELSE @VENCOD END AND 
		VENNOM LIKE(CASE WHEN @VENNOM = '' THEN VENNOM ELSE LTRIM(RTRIM(upper(@VENNOM))) END) 

	UNION 
	SELECT TOP 1
		0, 
		0,
		'SEM VENDEDOR' 
	FROM TBS004 (NOLOCK)
	WHERE 
		0 = CASE WHEN @VENCOD IS NULL THEN 0 ELSE @VENCOD END AND 
		'SEM VENDEDOR' LIKE(CASE WHEN @VENNOM = '' THEN 'SEM VENDEDOR' ELSE LTRIM(RTRIM(upper(@VENNOM))) END) 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Cria a tabela final explicitamente para ficar os campos ficarem visível para o ReportServer(Visual Studio)

	IF OBJECT_ID('tempdb.dbo.#CONTAS_RECEBER_FINAL') IS NOT NULL
		DROP TABLE #CONTAS_RECEBER_FINAL;

	CREATE TABLE #CONTAS_RECEBER_FINAL(
		SITUACAO varchar(50),
		SITUACAO_RESUMIDA varchar(10),
		SIT varchar(50),
		CONTADOR int,
		PFX varchar(3),
		TITULO int,		
		PAR char(2),
		TIPO char(3),
		COD_CLI int,
		CLINOM varchar(60),
		NOM_CLI varchar(60),
		VALOR_ORIGINAL money,
		EMISAO datetime,
		VENCIMENTO datetime,
		VENC_REAL datetime,
		BAIXA datetime,
		DIAS_ATRASO int,
		DIAS_PARA_VENCER int,
		CODBAI smallint,
		MOTBAI varchar(20),
		PORT smallint,
		PORTNOM varchar(20),
		TAXA smallmoney,
		JUROS money,
		ABATIMENTO money,
		ACRESCIMO money,
		RECEBIDO money,
		RESIDUO money,
		RESBANCO money,
		SALDO money,
		BANNUM decimal(9,0),
		OBS varchar(254),
		ANO_VENC_REAL varchar(4),
		MES_VENC_REAL varchar(2),
		DIA_VENC_REAL varchar(2),
		CLIEND varchar(400),
		CLICEP varchar(9),
		CLIMUNNOM varchar(35),
		VENCOD smallint,
		VENNOM varchar(50),
		CRENOSNUM varchar(20),
		HCRDES varchar(254),
		anoMesReal varchar(6)
		)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtrar os dados necessarios no conta a receber
	
	SET @Query	= N'
	If object_id(''tempdb.dbo.#CONTAS_RECEBER'') is not null
		DROP TABLE #CONTAS_RECEBER
	
	SELECT 
	CREEMPCOD,
	CLIEMPCOD,
	PFXEMPCOD,
	CREVENEMPCOD,
	CREVENCOD,
	CASE WHEN CREDATBAI = ''17530101'' AND CREDATVENREA > CONVERT(DATE,GETDATE())
		THEN ''À Receber à Vencer'' 
		ELSE 
			CASE WHEN CREDATBAI = ''17530101'' AND CREDATVENREA < CONVERT(DATE,GETDATE())
				THEN ''À Receber Vencido''
				ELSE
					CASE WHEN CREDATBAI = ''17530101'' AND CREDATVENREA = CONVERT(DATE,GETDATE())
						THEN ''À Receber Hoje''
						ELSE 
							CASE WHEN CREDATBAI <> ''17530101'' AND CREDATBAI > CREDATVENREA AND CREDATBAI <> CONVERT(DATE,GETDATE())
								THEN ''Recebido Atrasado''
								ELSE
									CASE WHEN CREDATBAI <> ''17530101'' AND CREDATBAI < CREDATVENREA AND CREDATBAI <> CONVERT(DATE,GETDATE())
										THEN ''Recebido Antecipado''
										ELSE
											CASE WHEN CREDATBAI <> ''17530101'' AND CREDATBAI = CREDATVENREA AND CREDATBAI <> CONVERT(DATE,GETDATE())
												THEN ''Recebido no Vencimento''
												ELSE
													CASE WHEN CREDATBAI <> ''17530101'' AND CREDATBAI = CONVERT(DATE,GETDATE())
														THEN ''Recebido Hoje''
														ELSE ''''
													END
											END
									END
							END
					END
			END
	END AS SITUACAO,

	CASE WHEN CREDATBAI = ''17530101'' AND CREDATVENREA > CONVERT(DATE,GETDATE())
		THEN ''À RVc	'' 
		ELSE 
			CASE WHEN CREDATBAI = ''17530101'' AND CREDATVENREA < CONVERT(DATE,GETDATE())
				THEN ''À RAt''
				ELSE
					CASE WHEN CREDATBAI = ''17530101'' AND CREDATVENREA = CONVERT(DATE,GETDATE())
						THEN ''À RHj''
						ELSE 
							CASE WHEN CREDATBAI <> ''17530101'' AND CREDATBAI > CREDATVENREA AND CREDATBAI <> CONVERT(DATE,GETDATE())
								THEN ''RAt''
								ELSE
									CASE WHEN CREDATBAI <> ''17530101'' AND CREDATBAI < CREDATVENREA AND CREDATBAI <> CONVERT(DATE,GETDATE())
										THEN ''RAn''
										ELSE
											CASE WHEN CREDATBAI <> ''17530101'' AND CREDATBAI = CREDATVENREA AND CREDATBAI <> CONVERT(DATE,GETDATE())
												THEN ''RVe''
												ELSE
													CASE WHEN CREDATBAI <> ''17530101'' AND CREDATBAI = CONVERT(DATE,GETDATE())
														THEN ''RHj''
														ELSE ''''
													END
											END
									END
							END
					END
			END
	END AS SITUACAO_RESUMIDA,

	CASE WHEN CREDATBAI <> ''17530101'' AND CREDATBAI = CONVERT(DATE,GETDATE()) AND CREDATVENREA = CREDATBAI
		THEN ''No Vencimento''
		ELSE 
			CASE WHEN CREDATBAI <> ''17530101'' AND CREDATBAI = CONVERT(DATE,GETDATE()) AND CREDATVENREA < CREDATBAI
				THEN ''Atrasado''
				ELSE
					CASE WHEN CREDATBAI <> ''17530101'' AND CREDATBAI = CONVERT(DATE,GETDATE()) AND CREDATVENREA > CREDATBAI
						THEN ''Antecipado''
						ELSE ''''
					END
			END
	END AS SIT2,
	1 AS CONTADOR,
	PFXCOD,
	CRETIT,
	CREPAR,
	TPTCOD,
	CLICOD,
	RTRIM(LTRIM(A.CRECLINOM)) AS NOM_CLI,
	CREVAL AS VALOR_ORIGINAL,
	CREDATEMI AS EMISAO,
	CREDATVEN AS VENCIMENTO,
	CREDATVENREA AS VENC_REAL,
	CREDATBAI AS BAIXA,
	dbo.CREDIAATR(CREEMPCOD,PFXEMPCOD,A.CLIEMPCOD,PFXCOD,CRETIT,CREPAR,A.CLICOD) AS DIAS_ATRASO,
	CASE WHEN DATEDIFF(DAY,GETDATE(),CREDATVENREA)<0 OR CONVERT(CHAR(10),CREDATBAI,103) <> ''01/01/1753'' 
		THEN 0 
		ELSE DATEDIFF(DAY,GETDATE(),CREDATVENREA) 
	END AS DIAS_PARA_VENCER,
	A.MOBCOD,
	A.PORCOD,
	CRETAXJUR AS TAXA,
	dbo.CREVALJUR(CREEMPCOD,PFXEMPCOD,A.CLIEMPCOD,PFXCOD,CRETIT,CREPAR,A.CLICOD) AS JUROS,
	CREVALABT AS ABATIMENTO,
	CREVALACR AS ACRESCIMO,
	CREVALREC AS RECEBIDO,
	CREVALRES AS RESIDUO,
	CRERESBAN AS RESBANCO,
	dbo.CREVALSDO(CREEMPCOD,PFXEMPCOD,A.CLIEMPCOD,PFXCOD,CRETIT,CREPAR,A.CLICOD) AS SALDO,
	CRENUMBAN AS BANNUM,
	RTRIM(LTRIM(CREOBS)) AS OBS,
	RTRIM(subString(convert(char(8),CREDATVENREA,112),1,4)) as ANO_VENC_REAL,
	LTRIM(RTRIM(subString(convert(char(8),CREDATVENREA,112),5,2))) as MES_VENC_REAL,
	LTRIM(RTRIM(subString(convert(char(8),CREDATVENREA,112),7,2))) as DIA_VENC_REAL,
	RTRIM(LTRIM(A.CRENOSNUM)) as CRENOSNUM

	INTO #CONTAS_RECEBER 

	FROM TBS056 A (NOLOCK)

	WHERE 
	CREEMPCOD = @empresaTBS056
	AND CREDATEMI BETWEEN @CREDATEMI_DE AND @CREDATEMI_ATE
	AND CREDATVENREA BETWEEN @CREDATVENREA_DE AND @CREDATVENREA_ATE
	AND CREDATBAI BETWEEN @CREDATBAI_DE AND @CREDATBAI_ATE
	AND CRETIT BETWEEN @CRETIT_DE AND @CRETIT_ATE
	AND PFXCOD IN (SELECT valor from #PREFIXOS)
	'	
	+
	IIf (@CLICOD = 0, '', ' AND CLICOD = @CLICOD')
	+
	IIf (@CRECLINOM = '', '', ' AND A.CRECLINOM LIKE LTRIM(RTRIM(UPPER(@CRECLINOM)))')
	+
	IIf (@PORCOD IS NULL, '', ' AND A.PORCOD = @PORCOD')
	+
	IIf (@VENCOD IS NULL, '', ' AND A.CREVENCOD = @VENCOD')
	+
	'
	If object_id(''tempdb.dbo.#RCB'') is not null
		drop table #RCB	

	SELECT 
	SITUACAO,
	SITUACAO_RESUMIDA,
	SIT2,
	CONTADOR,	
	PFXCOD AS PFX,
	CRETIT AS TITULO,
	CREPAR AS PAR,
	TPTCOD AS TIPO,
	A.CLICOD AS COD_CLI,
	NOM_CLI,
	VALOR_ORIGINAL,
	EMISAO,
	VENCIMENTO,
	VENC_REAL,
	BAIXA,
	DIAS_ATRASO,
	DIAS_PARA_VENCER,
	A.MOBCOD AS CODBAI,
	dbo.PrimeiraMaiuscula(RTRIM(ISNULL(D.MOBDES, ''EM ABERTO''))) AS MOTBAI,
	A.PORCOD AS PORT,
	ISNULL(PORNOM, '''') AS PORTNOM,
	TAXA,
	JUROS,
	ABATIMENTO,
	ACRESCIMO,
	RECEBIDO,
	RESIDUO,
	RESBANCO,
	SALDO,
	BANNUM,
	OBS,
	ANO_VENC_REAL,
	MES_VENC_REAL,
	DIA_VENC_REAL,

	RTRIM(LTRIM(B.CLINOM)) AS CLINOM,
	RTRIM(LTRIM(CLIEND)) + '', '' + RTRIM(LTRIM(CLINUM)) + '', '' + RTRIM(LTRIM(CLIBAI)) AS CLIEND,
	RTRIM(LTRIM(CLICEP)) AS CLICEP,
	RTRIM(LTRIM(ISNULL(G.MUNNOM, ''''))) AS CLIMUNNOM,

	C.VENCOD,
	C.VENNOM,
	CRENOSNUM,

	RTRIM(LTRIM(ISNULL(F.HCRDES, ''''))) AS HCRDES

	INTO #RCB
	
	FROM #CONTAS_RECEBER A (NOLOCK)
	INNER JOIN TBS002 B (NOLOCK)	ON A.CLIEMPCOD = B.CLIEMPCOD AND A.CLICOD = B.CLICOD
	INNER JOIN #TBS004 C (NOLOCK)	ON A.CREVENEMPCOD = C.VENEMPCOD AND A.CREVENCOD = C.VENCOD	
	LEFT JOIN TBS074 D (NOLOCK)		ON A.MOBCOD = D.MOBCOD
	LEFT JOIN TBS063 E (NOLOCK)		ON A.PORCOD = E.PORCOD
	LEFT JOIN TBS060 F (NOLOCK)		ON A.CREEMPCOD = F.HCREMPCOD AND A.PFXEMPCOD = F.HCRPFXEMPCOD AND A.CLIEMPCOD = F.HCRCLIEMPCOD AND A.PFXCOD = F.HCRPFXCOD AND
						     		   A.CRETIT = F.HCRTIT AND A.CREPAR = F.HCRPAR AND A.CLICOD = F.HCRCLICOD AND F.HCRACAO = ''B''
	LEFT JOIN TBS003 G (NOLOCK)		ON B.MUNCOD = G.MUNCOD

	-- Preenche a tabela final #CONTAS_RECEBER_FINAL
	INSERT INTO #CONTAS_RECEBER_FINAL

	SELECT 
	SITUACAO,
	SITUACAO_RESUMIDA,
	CASE WHEN SITUACAO = ''Recebido Hoje''
		THEN SITUACAO + '' - '' + SIT2
		ELSE SITUACAO
	END AS SIT, 
	CONTADOR,
	PFX,
	TITULO,
	PAR,
	TIPO,
	COD_CLI,
	CLINOM,
	NOM_CLI,
	VALOR_ORIGINAL,
	EMISAO,
	VENCIMENTO,
	VENC_REAL,
	BAIXA,
	DIAS_ATRASO,
	DIAS_PARA_VENCER,
	CODBAI,
	MOTBAI,
	PORT,
	PORTNOM,
	TAXA,
	JUROS,
	ABATIMENTO,
	ACRESCIMO,
	RECEBIDO,
	RESIDUO,
	RESBANCO,
	SALDO,
	BANNUM,
	OBS,
	ANO_VENC_REAL,
	MES_VENC_REAL,
	DIA_VENC_REAL,
	CLIEND,
	CLICEP,
	CLIMUNNOM,
	VENCOD,
	VENNOM,
	CRENOSNUM,
	HCRDES,
	ANO_VENC_REAL + MES_VENC_REAL as anoMesReal

	FROM #RCB
	'
	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS056 int, 
	                @CREDATEMI_DE datetime, @CREDATEMI_ATE datetime,
					@CREDATVENREA_DE datetime, @CREDATVENREA_ATE datetime,
					@CREDATBAI_DE datetime, @CREDATBAI_ATE datetime,
					@CRETIT_DE int, @CRETIT_ATE int,
					@CRECLINOM varchar(60), @PORCOD int, @CLICOD int, @VENCOD int'


	EXEC sp_executesql @Query, @ParmDef, @empresaTBS056, 
					   @CREDATEMI_DE, @CREDATEMI_ATE,
					   @CREDATVENREA_DE, @CREDATVENREA_ATE,
					   @CREDATBAI_DE, @CREDATBAI_ATE,
					   @CRETIT_DE, @CRETIT_ATE,
					   @CRECLINOM, @PORCOD, @CLICOD, @VENCOD
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Select final...

	SELECT
		* 
	FROM #CONTAS_RECEBER_FINAL

	WHERE
		SITUACAO COLLATE DATABASE_DEFAULT IN (SELECT valor FROM #OPCOES) AND
		MOTBAI COLLATE DATABASE_DEFAULT IN (SELECT valor FROM #MOTIVOS)
End
