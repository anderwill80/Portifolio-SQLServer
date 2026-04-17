/*
====================================================================================================================================================================================
WREL013 - Contas a Pagar
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
30/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
15/02/2024 WILLIAM
	- Criação da tabela final #CONTAS_PAGAR em vez de usar o "select...;With", para que o ReportServer reconheça os campos;
	- Uso da função "fSplit" para transformar os filtros multi-valores em tabelas, para facilitar condições via cláusula "IN()";
14/02/2024 WILLIAM
	- Conversão para Stored procedure;
	- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros;
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", SQL deixa de verificar SP no BD Master, buscando direto no SIBD;
	- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas;
====================================================================================================================================================================================
*/
--CREATE PROC [dbo].[usp_RS_ContasPagar]
ALTER PROC [dbo].[usp_RS_ContasPagar]
	@empcod smallint,
	@DataDeE datetime	= null,
	@DataAteE datetime	= null,
	@VencDe datetime	= null,
	@VencAte datetime	= null,
	@BaiDe datetime		= null,
	@BaiAte datetime	= null,
	@TituloDe decimal(10,0)		= null,
	@TituloAte decimal(10,0)	= null,
	@NomFor varchar(50)	= '',
	@Portador int		= null,
	@codfor int			= 0,
	@PFXCOD varchar(500)= '',
	@Opcao varchar(500)	= '',
	@motbai varchar(500)= ''
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	DECLARE	@empresaTBS057 smallint, @codigoEmpresa smallint,
			@CPADATEMI_DE datetime, @CPADATEMI_ATE datetime, @CPADATVENREA_DE datetime, @CPADATVENREA_ATE datetime,	@CPADATBAI_DE datetime, @CPADATBAI_ATE datetime,
			@CPATIT_DE decimal(10,0), @CPATIT_ATE decimal(10,0), @CPAFORNOM varchar(50), @PORCOD int, @FORCOD int, @prefixos varchar(500), @Opcoes varchar(500), @Motivos varchar(500),
			@Query nvarchar (MAX), @ParmDef nvarchar (500);
				
-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;		
	SET @CPADATEMI_DE = CASE WHEN @DataDeE IS NULL THEN '17530101' ELSE @DataDeE END;
	SET @CPADATEMI_ATE = CASE WHEN @DataAteE IS NULL THEN DATEADD(year, 5, GETDATE()) ELSE @DataAteE END;
	SET @CPADATVENREA_DE = CASE WHEN @VencDe IS NULL THEN '17530101' ELSE @VencDe END;
	SET @CPADATVENREA_ATE = CASE WHEN @VencAte IS NULL THEN DATEADD(year, 5, GETDATE()) ELSE @VencAte END;
	SET @CPADATBAI_DE = CASE WHEN @BaiDe IS NULL THEN '17530101' ELSE @BaiDe END;
	SET @CPADATBAI_ATE = CASE WHEN @BaiAte IS NULL THEN DATEADD(year, 5, GETDATE()) ELSE @BaiAte END;
	SET @CPATIT_DE = CASE WHEN @TituloDe IS NULL THEN 0 ELSE @TituloDe END;
	SET @CPATIT_ATE = CASE WHEN @TituloAte IS NULL THEN 9999999999 ELSE @TituloAte END;
	SET @CPAFORNOM = @NomFor;
	SET @PORCOD = @Portador;
	SET @FORCOD = @codfor;
	SET @prefixos = @PFXCOD;
	SET @Opcoes = @Opcao;
	SET @Motivos = @motbai;

-- Quebra os filtros Multi-valores em tabelas via função "Split", para facilitar a cláusula "IN()"
	If object_id('TempDB.dbo.#PREFIXOS') is not null
		DROP TABLE #PREFIXOS;
	If object_id('TempDB.dbo.#OPCOES') is not null
		DROP TABLE #OPCOES;
	If object_id('TempDB.dbo.#MOTIVOS') is not null
		DROP TABLE #MOTIVOS;
		
    SELECT 
		elemento AS valor
	INTO #PREFIXOS FROM fSplit(@prefixos, ',')

    SELECT 
		elemento AS valor
	INTO #OPCOES FROM fSplit(@Opcoes, ',')

    SELECT
		elemento AS valor
	INTO #MOTIVOS FROM fSplit(@Motivos, ',')

-- Verificar se a tabela é compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS057', @empresaTBS057 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	If OBJECT_ID('TempDB.dbo.#CONTAS_PAGAR') IS NOT NULL
		DROP TABLE #CONTAS_PAGAR;
		
	SELECT TOP 0
		CASE WHEN CPADATBAI = '17530101' AND CPADATVENREA >= CONVERT(DATE,GETDATE())
		THEN 'Em Aberto a Vencer'
		ELSE 
			CASE WHEN CPADATBAI = '17530101' AND CPADATVENREA < CONVERT(DATE,GETDATE())
			THEN 'Em Aberto Atrasado'
			ELSE
				CASE WHEN CPADATBAI <> '17530101' AND CPADATBAI > CPADATVENREA
				THEN 'Pago Atrasado'
				ELSE
					CASE WHEN CPADATBAI <> '17530101' AND CPADATBAI < CPADATVENREA
					THEN 'Pago Antes de Vencer'
					ELSE
						CASE WHEN CPADATBAI <> '17530101' AND CPADATBAI = CPADATVENREA
						THEN 'Pago no Vencimento'
						ELSE ''
						END
					END
				END
			END
		END AS SITUACAO,

		CASE WHEN CPADATBAI = '17530101' AND CPADATVENREA >= CONVERT(DATE,GETDATE())
		THEN 'AV'
		ELSE 
			CASE WHEN CPADATBAI = '17530101' AND CPADATVENREA < CONVERT(DATE,GETDATE())
			THEN 'AA'
			ELSE
				CASE WHEN CPADATBAI <> '17530101' AND CPADATBAI > CPADATVENREA
				THEN 'PA'
				ELSE
					CASE WHEN CPADATBAI <> '17530101' AND CPADATBAI < CPADATVENREA
					THEN 'PAV'
					ELSE
						CASE WHEN CPADATBAI <> '17530101' AND CPADATBAI = CPADATVENREA
						THEN 'PV'
						ELSE ''
						END
					END
				END
			END
		END AS SITUACAO_RESUMIDA,

		1 AS CONTADOR,
		PFXCOD AS PFX,
		CPATIT AS TITULO,
		CPAPAR AS PAR,
		TPTCOD AS TIPO,
		PORCOD AS PORT,
		CPADATEMI AS DATA_EMI,
		CPADATVENREA AS VENC_REAL,
		CPADATBAI AS BAIXA,
		subString(convert(char(8),CPADATVENREA,112),1,4) AS ANO_VEN_REAL,
		subString(convert(char(8),CPADATVENREA,112),5,2) AS MES_VEN_REAL,
		subString(convert(char(8),CPADATVENREA,112),7,2) AS DIA_VEN_REAL,
		CASE WHEN DATEDIFF(DAY,GETDATE(),CPADATVENREA)<0 OR CPADATBAI > '17530101' THEN 0 ELSE DATEDIFF(DAY,GETDATE(),CPADATVENREA) END AS DIAS_PARA_VENCER,
		dbo.CPADIAATR(CPAEMPCOD,PFXEMPCOD,A.FOREMPCOD,PFXCOD,CPATIT,CPAPAR,A.FORCOD) AS DIA_ATRA,
		CPAVAL AS VALOR_ORIG,
		CPAVALRES AS RESIDUO,
		CPAVALABT AS ABATIMENTO,
		CPAVALACR AS ACRESCIMO,
		CPAVALPAG AS VALOR_PAGO,
		dbo.CPAVALSDO(CPAEMPCOD,PFXEMPCOD,A.FOREMPCOD,PFXCOD,CPATIT,CPAPAR,A.FORCOD) as SALDO_ABERTO,
		A.MOBCOD AS CODBAI,
		dbo.PrimeiraMaiuscula(rtrim(ISNULL(D.MOBDES,'EM ABERTO'))) AS MOTBAI,
		RTRIM(LTRIM(CPAOBS)) AS OBS,
		A.FORCOD AS COD_FOR,
		RTRIM(A.CPAFORNOM) AS FORNECEDOR,
		RTRIM(LTRIM(FOREND)) + ' , ' + RTRIM(LTRIM(FORNUM)) + ' , ' + RTRIM(LTRIM(FORBAI)) AS ENDFOR,
		RTRIM(LTRIM(FORCEP)) AS CEPFOR,
		RTRIM(LTRIM(ISNULL(C.MUNNOM, ''))) AS MUNFOR

	INTO #CONTAS_PAGAR FROM TBS057 A (NOLOCK)
		LEFT JOIN TBS074 D (NOLOCK) ON A.MOBEMPCOD = D.MOBEMPCOD AND A.MOBCOD = D.MOBCOD
		LEFT JOIN TBS006 B (NOLOCK) ON A.FOREMPCOD = B.FOREMPCOD AND A.FORCOD = B.FORCOD
		LEFT JOIN TBS003 C (NOLOCK) ON B.MUNCOD = C.MUNCOD				  	

	-- Monta a query dinâmica...
	SET @Query	= N'
	INSERT INTO #CONTAS_PAGAR

	SELECT 
	CASE WHEN CPADATBAI = ''17530101'' AND CPADATVENREA >= CONVERT(DATE,GETDATE())
	THEN ''Em Aberto a Vencer''
	ELSE 
		CASE WHEN CPADATBAI = ''17530101'' AND CPADATVENREA < CONVERT(DATE,GETDATE())
		THEN ''Em Aberto Atrasado''
		ELSE
			CASE WHEN CPADATBAI <> ''17530101'' AND CPADATBAI > CPADATVENREA
			THEN ''Pago Atrasado''
			ELSE
				CASE WHEN CPADATBAI <> ''17530101'' AND CPADATBAI < CPADATVENREA
				THEN ''Pago Antes de Vencer''
				ELSE
					CASE WHEN CPADATBAI <> ''17530101'' AND CPADATBAI = CPADATVENREA
					THEN ''Pago no Vencimento''
					ELSE ''''
					END
				END
			END
		END
	END AS SITUACAO,

	CASE WHEN CPADATBAI = ''17530101'' AND CPADATVENREA >= CONVERT(DATE,GETDATE())
	THEN ''AV''
	ELSE 
		CASE WHEN CPADATBAI = ''17530101'' AND CPADATVENREA < CONVERT(DATE,GETDATE())
		THEN ''AA''
		ELSE
			CASE WHEN CPADATBAI <> ''17530101'' AND CPADATBAI > CPADATVENREA
			THEN ''PA''
			ELSE
				CASE WHEN CPADATBAI <> ''17530101'' AND CPADATBAI < CPADATVENREA
				THEN ''PAV''
				ELSE
					CASE WHEN CPADATBAI <> ''17530101'' AND CPADATBAI = CPADATVENREA
					THEN ''PV''
					ELSE ''''
					END
				END
			END
		END
	END AS SITUACAO_RESUMIDA,

	1 AS CONTADOR,
	PFXCOD AS PFX,
	CPATIT AS TITULO,
	CPAPAR AS PAR,
	TPTCOD AS TIPO,
	PORCOD AS PORT,
	CPADATEMI AS DATA_EMI,
	CPADATVENREA AS VENC_REAL,
	CPADATBAI AS BAIXA,
	subString(convert(char(8),CPADATVENREA,112),1,4) AS ANO_VEN_REAL,
	subString(convert(char(8),CPADATVENREA,112),5,2) AS MES_VEN_REAL,
	subString(convert(char(8),CPADATVENREA,112),7,2) AS DIA_VEN_REAL,
	CASE WHEN DATEDIFF(DAY,GETDATE(),CPADATVENREA)<0 OR CPADATBAI > ''17530101'' THEN 0 ELSE DATEDIFF(DAY,GETDATE(),CPADATVENREA) END AS DIAS_PARA_VENCER,
	dbo.CPADIAATR(CPAEMPCOD,PFXEMPCOD,A.FOREMPCOD,PFXCOD,CPATIT,CPAPAR,A.FORCOD) AS DIA_ATRA,
	CPAVAL AS VALOR_ORIG,
	CPAVALRES AS RESIDUO,
	CPAVALABT AS ABATIMENTO,
	CPAVALACR AS ACRESCIMO,
	CPAVALPAG AS VALOR_PAGO,
	dbo.CPAVALSDO(CPAEMPCOD,PFXEMPCOD,A.FOREMPCOD,PFXCOD,CPATIT,CPAPAR,A.FORCOD) as SALDO_ABERTO,
	A.MOBCOD AS CODBAI,
	dbo.PrimeiraMaiuscula(rtrim(ISNULL(D.MOBDES,''EM ABERTO''))) AS MOTBAI,
	RTRIM(LTRIM(CPAOBS)) AS OBS,
	A.FORCOD AS COD_FOR,
	RTRIM(A.CPAFORNOM) AS FORNECEDOR,
	RTRIM(LTRIM(FOREND)) +'' , ''+ RTRIM(LTRIM(FORNUM)) + '' , '' + RTRIM(LTRIM(FORBAI)) AS ENDFOR,
	RTRIM(LTRIM(FORCEP)) AS CEPFOR,
	RTRIM(LTRIM(ISNULL(C.MUNNOM,''''))) AS MUNFOR
	
	FROM TBS057 A (NOLOCK)
	LEFT JOIN TBS074 D (NOLOCK) ON A.MOBEMPCOD = D.MOBEMPCOD AND A.MOBCOD = D.MOBCOD
	LEFT JOIN TBS006 B (NOLOCK) ON A.FOREMPCOD = B.FOREMPCOD AND A.FORCOD = B.FORCOD
	LEFT JOIN TBS003 C (NOLOCK) ON B.MUNCOD = C.MUNCOD
				  	
	WHERE 
	CPAEMPCOD = @empresaTBS057 AND
	CPADATEMI BETWEEN @CPADATEMI_DE AND @CPADATEMI_ATE AND
	CPADATVENREA BETWEEN @CPADATVENREA_DE AND @CPADATVENREA_ATE AND 
	CPADATBAI BETWEEN @CPADATBAI_DE AND @CPADATBAI_ATE AND
	CPATIT BETWEEN @CPATIT_DE AND @CPATIT_ATE AND
	PFXCOD IN (SELECT valor from #PREFIXOS)
	'
	+
	IIf (@CPAFORNOM = '', '', ' AND A.CPAFORNOM LIKE LTRIM(RTRIM(upper(@CPAFORNOM)))')
	+
	IIf (@PORCOD IS NULL, '', ' AND PORCOD = @PORCOD')
	+
	IIf (@FORCOD = 0, '', ' AND A.FORCOD = @FORCOD')		
	
	--select @Query

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS057 int, @CPADATEMI_DE datetime, @CPADATEMI_ATE datetime, @CPADATVENREA_DE datetime, @CPADATVENREA_ATE datetime, @CPADATBAI_DE datetime, 
					@CPADATBAI_ATE datetime, @CPATIT_DE decimal(10, 0), @CPATIT_ATE decimal(10, 0),	@CPAFORNOM varchar(50), @PORCOD int, @FORCOD int'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS057, @CPADATEMI_DE, @CPADATEMI_ATE, @CPADATVENREA_DE, @CPADATVENREA_ATE, @CPADATBAI_DE, @CPADATBAI_ATE,
					   @CPATIT_DE, @CPATIT_ATE, @CPAFORNOM, @PORCOD, @FORCOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final para o ReportServer reconhecer os campos	
	SELECT
		*
	FROM #CONTAS_PAGAR
	WHERE	
		SITUACAO IN (SELECT valor from #OPCOES) AND
		MOTBAI IN (SELECT valor from #MOTIVOS)
End
