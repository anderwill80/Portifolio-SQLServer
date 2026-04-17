/*
====================================================================================================================================================================================
WREL106 - Localizacao por Notas de Entrada
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
31/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
	- Correcao ao atribuir "SET @DATA_ATE = @DATADE";
07/03/2024	ANDERSON WILLIAM
	- Conversão para Stored procedure;
	- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros;
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela",  SQL deixa de verificar SP no BD Master, buscando direto no SIBD;
	- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas;
	- Uso da função "fSplit" para transformar os filtros multi-valores em tabelas, para facilitar condições via cláusula "IN()";										
	- Inclusão de filtro na TBS080, verificando se o tipo "D" de devolução foi selecionado pelo usuário nos parâmetros do relatório, 
	isso evitará trazer registros de notas de entrada de devolução desnecessária, caso usuário opte por exemplo em filtrar apenas notas de compra("N)"
====================================================================================================================================================================================
*/
ALTER PROC [dbo].[usp_RS_LocalizacaoPorNotaEntrada]
--CREATE PROC [dbo].[usp_RS_LocalizacaoPorNotaEntrada2]
	@empcod smallint,
	@DATADE datetime,
	@DATAATE datetime,
	@NFENUM decimal(10,0) = 0,
	@NFECOD	int	= 0,
	@NFETIP varchar(20)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	DECLARE	@codigoEmpresa smallint, @empresaTBS002 int, @empresaTBS010 int, @empresaTBS059 int, @empresaTBS080 int, @empresaTBS055 int,
			@DATA_DE datetime, @DATA_ATE datetime, @Nota decimal(10,0), @EmiRem	int, @Tipos varchar(20),
			@Query nvarchar (MAX), @ParmDef nvarchar (500);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @DATA_DE = @DATADE;
	SET @DATA_ATE = @DATAATE;
	SET @Nota = @NFENUM;
	SET @EmiRem = @NFECOD;
	SET @Tipos = @NFETIP;

-- Quebra os filtros Multi-valores em tabelas via função "Split", para facilitar a cláusula "IN()"
	IF OBJECT_ID('tempdb.dbo.#TIPOS') IS NOT NULL
		DROP TABLE #TIPOS;
    SELECT 
		elemento as valor
	INTO #TIPOS FROM fSplit(@Tipos, ',')

-- Verificar se a tabela é compartilhada ou exclusiva
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS002', @empresaTBS002 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS055', @empresaTBS055 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS059', @empresaTBS059 output;
	EXEC dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS080', @empresaTBS080 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- PEGAS AS NOTAS DE ENTRADA DE DEVOLUÇÃO QUE FORAM AUTORIZADAS

	IF OBJECT_ID('tempdb.dbo.#TBS080') IS NOT NULL
		DROP TABLE #TBS080;
   
	-- Select TOP 0 para criar apenas a tabela com a estrutura da tabela original
	SELECT TOP 0
		ENFEMPCOD,
		SNEEMPCOD,
		ENFNUM,
		SNESER,
		ENFTIPDOC,
		ENFFINEMI,
		ENFCODDES,
		ENFCNPJCPF
	INTO #TBS080 FROM TBS080 (NOLOCK)

	-- Só irá fazer o select na TBS080, se o tipo "D" estiver sido escolhido nos parâmetros
	If ('D' IN(SELECT valor FROM #TIPOS))
	Begin
		-- Monta a query dinamica
		SET @Query	= N'
		INSERT INTO #TBS080

		SELECT
			ENFEMPCOD,
			SNEEMPCOD,
			ENFNUM,
			SNESER,
			ENFTIPDOC,
			ENFFINEMI,
			ENFCODDES,
			ENFCNPJCPF	
		FROM TBS080 (NOLOCK)
		WHERE 
			ENFEMPCOD = @empresaTBS080 AND
			ENFDATEMI BETWEEN @DATA_DE AND @DATA_ATE AND 
			ENFSIT = 6 AND
			ENFTIPDOC = 0	
		'
		-- Executa a Query dinâminca(QD)
		SET @ParmDef = N'@empresaTBS080 int, @DATA_DE datetime, @DATA_ATE datetime'

		EXEC sp_executesql @Query, @ParmDef, @empresaTBS080, @DATA_DE, @DATA_ATE
	End

--	select @empresaTBS080, @DATA_DE, @DATA_ATE;

--	select * from #TBS080;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- SELECIONANDO AS NOTAS DE ENTRADA

	IF OBJECT_ID ('tempdb.dbo.#TBS059') IS NOT NULL
		DROP TABLE #TBS059;

	-- Select TOP 0 para criar apenas a tabela com a estrutura da tabela original
	SELECT TOP 0
		A.NFEEMPCOD,
		A.NFETIP,
		A.NFENUM,
		A.NFECOD,
		A.SEREMPCOD,
		A.SERCOD,
		A.NFEITE,
		A.LESCOD,
		A.PROCOD,
		dbo.PrimeiraMaiuscula(rtrim(ltrim(B.NFENOM))) as NFENOM,
		B.NFEDATEFE + B.NFEHOREFE AS NFEDATEFE,
		dbo.PrimeiraMaiuscula(rtrim(ltrim(B.NFEUSUEFE))) as NFEUSUEFE,
		CASE B.NFETIP 
			WHEN 'N' THEN 'Compra'
			WHEN 'T' THEN 'Transferência'
			WHEN 'D' THEN 'Devolução'
			WHEN 'C' THEN 'Complemento'
			ELSE ''
		END AS NFETIPDESC,
		A.NFEQTD,
		case B.NFECONFIS
			when 0 then 'Nao'
			when 1 then 'Sim'
			when 2 then 'Sim D'
			else ''
		end NFECONFIS
	INTO #TBS059 FROM TBS0591 A (NOLOCK) 
		INNER JOIN TBS059 B (NOLOCK) ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFECOD = B.NFECOD AND A.NFENUM = B.NFENUM AND A.NFETIP = B.NFETIP AND A.SERCOD = B.SERCOD AND A.SEREMPCOD = B.SEREMPCOD
		LEFT JOIN #TBS080 D (NOLOCK) ON A.NFENUM = D.ENFNUM AND A.NFECOD = D.ENFCODDES

	-- Monta a query dinamica...
	SET @Query	= N'
	INSERT INTO #TBS059

	SELECT 
		A.NFEEMPCOD,
		A.NFETIP,
		A.NFENUM,
		A.NFECOD,
		A.SEREMPCOD,
		A.SERCOD,
		A.NFEITE,
		A.LESCOD,
		A.PROCOD,
		dbo.PrimeiraMaiuscula(rtrim(ltrim(B.NFENOM))) as NFENOM,
		B.NFEDATEFE + B.NFEHOREFE AS NFEDATEFE,
		dbo.PrimeiraMaiuscula(rtrim(ltrim(B.NFEUSUEFE))) as NFEUSUEFE,
		CASE B.NFETIP 
			WHEN ''N'' THEN ''Compra''
			WHEN ''T'' THEN ''Transferência''
			WHEN ''D'' THEN ''Devolução''
			WHEN ''C'' THEN ''Complemento''
			ELSE ''''
		END AS NFETIPDESC,
		A.NFEQTD,
		case B.NFECONFIS
			when 0 then ''Nao''
			when 1 then ''Sim''
			when 2 then ''Sim D''
			else ''''
		end NFECONFIS
	FROM TBS0591 A (NOLOCK)
		INNER JOIN TBS059 B (NOLOCK) ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFECOD = B.NFECOD AND A.NFENUM = B.NFENUM AND A.NFETIP = B.NFETIP AND A.SERCOD = B.SERCOD AND A.SEREMPCOD = B.SEREMPCOD
		LEFT JOIN #TBS080 D (NOLOCK) ON A.NFENUM = D.ENFNUM AND A.NFECOD = D.ENFCODDES

	WHERE 
		A.NFEEMPCOD	= @empresaTBS059 AND
		B.NFEDATEFE	BETWEEN @DATA_DE AND @DATA_ATE AND
		(D.ENFTIPDOC IS NOT NULL OR (NFENOSFOR <> ''S'' AND NFEDATEFE <> '''' )) AND
		B.NFECAN	<> ''S'' AND
		B.NFETIP IN (SELECT valor from #TIPOS)
	'
	+
	IIf (@Nota <= 0, '', ' AND A.NFENUM = @Nota')
	+
	IIf (@EmiRem <= 0, '', ' AND A.NFECOD = @EmiRem')

		-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS059 int, @DATA_DE datetime, @DATA_ATE datetime, @Nota decimal(10,0), @EmiRem int'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS059, @DATA_DE, @DATA_ATE, @Nota, @EmiRem
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- pegar as quantidades totais reservadas de cada item que entrou na nota autorizada/efetivada

	IF OBJECT_ID ('TEMPDB.DBO.#TBS05921') IS NOT NULL
		DROP TABLE #TBS05921;

	SELECT 
		B.*,
		isnull(A.NFETIPPED,'') as NFETIPPED,
		isnull(NFEPEDNUM,0) as NFEPEDNUM,
		isnull(NFEPEDEMB * NFEATEQTD,0) as NFEATEQTD,
		isnull(NFEATESEQ,'') as NFEATESEQ 
	INTO #TBS05921 FROM #TBS059 B (NOLOCK)
		LEFT JOIN TBS0592 A ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFETIP = B.NFETIP AND A.NFENUM = B.NFENUM AND A.NFECOD = B.NFECOD AND A.SEREMPCOD = B.SEREMPCOD AND A.SERCOD = B.SERCOD AND A.NFEITE = B.NFEITE
	ORDER BY 
		A.NFEATEDAT, 
		NFEATESEQ

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Zerar as quantidades de compras, porque só estou vendo as vendas e solicitações

	UPDATE #TBS05921 SET 
		NFETIPPED = '',
		NFEPEDNUM = 0,
		NFEATEQTD = 0,
		NFEATESEQ = ''
	WHERE 
		NFETIPPED = 'C'

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Pegar nome conferente

	IF OBJECT_ID ('tempdb.dbo.#TBS0592') IS NOT NULL
		DROP TABLE #TBS0592;

	SELECT 
		B.*,
		isnull(dbo.PrimeiraMaiuscula(rtrim(ltrim(CFCUSUFIN))),'') as CFCUSUFIN
	INTO #TBS0592 FROM #TBS05921 B (NOLOCK)
		LEFT JOIN TBS133 A (NOLOCK) ON A.CFCNFEEMPCOD = B.NFEEMPCOD AND A.CFCNFETIP = B.NFETIP AND A.CFCNFENUM = B.NFENUM AND A.CFCSERCOD = B.SERCOD AND A.CFCNFECOD = B.NFECOD

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Qual cliente é o pedido de vendas 

	IF OBJECT_ID ('tempdb.dbo.#TBS055') IS NOT NULL
		DROP TABLE #TBS055;

	SELECT
		PDVNUM, 
		PDVCLICOD, 
		dbo.PrimeiraMaiuscula(rtrim(ltrim(PDVCLINOM))) as PDVCLINOM, 
		VENCOD, 
		(SELECT dbo.PrimeiraMaiuscula(rtrim(ltrim(VENNOM))) from TBS004 B (nolock) where A.VENCOD = B.VENCOD) as VENNOM
	INTO #TBS055 FROM TBS055 A (NOLOCK) 
	
	WHERE 
		PDVEMPCOD = @empresaTBS055 AND
		PDVNUM IN (SELECT NFEPEDNUM FROM #TBS0592 WHERE NFEPEDNUM > 0 AND NFETIPPED = 'V')

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- PEGANDO OS PRODUTOS NA TBS010 QUE APARECERAM NAS NOTAS ACIMA

	IF OBJECT_ID ('tempdb.dbo.#TBS010') IS NOT NULL
		DROP TABLE #TBS010;	

	SELECT
		PROSTATUS,
		case when len(A.MARCOD) = 4 
			then rtrim(A.MARCOD) + ' - ' + rtrim(A.MARNOM) 
			else right(('00' + ltrim(str(A.MARCOD))),3) + ' - ' + rtrim(A.MARNOM)
		end as MARCOD,
		RTRIM(LTRIM(A.PROCOD)) AS PROCOD, 
		RTRIM(LTRIM(PRODES)) AS PRODES,
		rtrim(ltrim(PROLOCFIS)) AS PROLOCFIS,
		rtrim(ltrim(PROSETLOJ1)) AS PROSETLOJ1,
		rtrim(ltrim(PROSETLOJ2)) AS PROSETLOJ2,
		CASE WHEN PROUM1QTD > 1
			THEN RTRIM(LTRIM(PROUM1)) + ' ' + RTRIM(CONVERT(DECIMAL, PROUM1QTD, 0)) + '' + 
				CASE WHEN PROUMV = '' 
					THEN PROUM1 
					ELSE PROUMV 
				END 
			ELSE RTRIM(CONVERT(DECIMAL, PROUM1QTD, 0)) + '' + 
				CASE WHEN PROUMV = '' 
					THEN PROUM1 
					ELSE PROUMV 
				END 
		END AS UN1
	INTO #TBS010 FROM TBS010 A (NOLOCK) 

	WHERE 
		PROEMPCOD = @empresaTBS010 AND
		A.PROCOD IN (SELECT PROCOD FROM #TBS059) 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA FINAL

	SELECT 
		B.*,
		A.PROSTATUS,
		A.MARCOD, 
		dbo.PrimeiraMaiuscula(A.PRODES) AS PRODES, 
		dbo.PrimeiraMaiuscula(A.UN1) as UN1,
		case when B.LESCOD = 1 
			then A.PROLOCFIS 
			else 
				case when B.LESCOD = 2 
					then 
						case when rtrim(ltrim(A.PROSETLOJ1)) <> '' and rtrim(ltrim(A.PROSETLOJ2)) <> '' 
							then A.PROSETLOJ1 + ' ; ' + A.PROSETLOJ2 
							else
								case when rtrim(ltrim(A.PROSETLOJ1)) = '' and rtrim(ltrim(A.PROSETLOJ2)) <> ''
									then A.PROSETLOJ2
									else A.PROSETLOJ1  
								end
						end
					else ''
				end
		end as PROLOCFIS, 
		dbo.PrimeiraMaiuscula(C.LESDES) AS LESDES,
		isnull(D.PDVCLICOD,0) as CLICOD ,
		isnull(D.PDVCLINOM,'') as CLINOM,
		isnull(D.VENCOD,0) as VENCOD,
		isnull(D.VENNOM,'') as VENNOM
	FROM #TBS010 A 
		INNER JOIN #TBS0592 B ON A.PROCOD = B.PROCOD
		LEFT JOIN #TBS055 D ON B.NFEPEDNUM = D.PDVNUM
		LEFT JOIN TBS034 C (NOLOCK) ON B.LESCOD = C.LESCOD
	ORDER BY 
		NFEDATEFE, 
		NFENUM,
		NFEITE,
		NFEATESEQ
END

GO