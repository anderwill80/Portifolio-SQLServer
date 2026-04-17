/*
====================================================================================================================================================================================
WREL095 - Etiquetas Loja
====================================================================================================================================================================================
Histórico de alterações
====================================================================================================================================================================================
27/01/2025 WILLIAM
	- Aplicar refinamento no codigo;
	- Utilizacao da SP "usp_GetCodigoProdutos";
	- Leitura do parametro 1134, para obter o codigo do local de estoque de loja, para atender BestArts, já que lá estoque de loja é 1;
20/06/2024 WILLIAM		
	- Limpeza do código, retirando criação da tabela MSL002, que obtém dados de vendas dos produtos, que não está sendo usado nas etiquetas
06/03/2024 WILLIAM			
	- Correção nos filtros para obter os preços da tabela TBS031;
27/02/2024 WILLIAM			
	- Inclusão da 4a Unidade de medidada, para permitir usuário imprimir preços do atacado até a 4aUM;
26/02/2024 WILLIAM			
	- Conversão para Stored procedure
	- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
	- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", SQL deixa de verificar SP no BD Master, buscando direto no SIBD
	- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas																				
====================================================================================================================================================================================
*/
ALTER PROC [dbo].[usp_RS_EtiquetasLoja]
--create proc [dbo].[usp_RS_EtiquetasLoja]
	@empcod smallint,
	@COD  varchar(8000),
	@STA varchar(20), 
	@Loces varchar(8000),
	@dataDE datetime	= null,
	@dataAte datetime	= null,
	@PRODES varchar(60) = '',
	@MARCOD int = 0,
	@MARNON varchar(30) = '',	-- Nome está errado, porém deixei assim para não precisar alterar todos os relatórios
	@A int,
	@somenteComSaldo char(1)	
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais

	declare	@codigoEmpresa smallint, @empresaTBS010 int, @empresaTBS031 int,			
			@PROCOD varchar(8000), @BARRAS1 varchar(8000), @LOCLOJA varchar(8000), @STATUS varchar(20),
			@ImpMediaSemanal char(1), @data_DE datetime, @data_ATE datetime, @ComSaldo char(1), @Disponivel decimal(12,6),
			@DescricaoPro varchar(60), @CodMarca int, @MarcaNome varchar(30), @LocalLoja int, @QtdEtiquetas int,
			@cmdSQL nvarchar (MAX), @ParmDef nvarchar (500);

-- Desativando a detecção de parâmetros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @BARRAS1 = REPLACE(REPLACE(@COD, ',', ''','''), ' ', '');
	SET @LOCLOJA = REPLACE(REPLACE(@Loces, ',', ''','''), ' ', '');	-- NAO UTILIZADO MAIS
	SET @STATUS = REPLACE(REPLACE(@STA, ',', ''','''), ' ', '');
	SET @PROCOD = @COD;
	SET @data_DE = (select isnull(@dataDE, '01/01/1753'));
	SET @data_ATE = (select isnull(@dataAte, GETDATE()));
	SET @ComSaldo = @somenteComSaldo;
	SET @Disponivel = IIf(@ComSaldo = 'N', -999999, 0);
	SET @DescricaoPro = UPPER(RTRIM(@PRODES));
	SET @CodMarca = @MARCOD;
	SET	@MarcaNome = UPPER(RTRIM(@MARNON));
	SET @QtdEtiquetas = @A

	-- Obtem local de estoque da loja, via parametro
	SET @LocalLoja = Convert(int, (SELECT PARVAL FROM TBS025 (NOLOCK) WHERE PARCHV = 1134));
	-- Caso parametro nao definido, seta por padrao o local 2
	If @LocalLoja = 0
		set @LocalLoja = 2;

-- Verificar se a tabela é compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS031', @empresaTBS031 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtra produto pelo código ou código de barras, se vazio filtra todos os código da TBS010, via SP

	If OBJECT_ID ('tempdb.dbo.#T') IS NOT NULL
		DROP TABLE #T;

	CREATE TABLE #T (PROCOD VARCHAR(15))

	INSERT INTO #T
	EXEC usp_GetCodigosProdutos @codigoEmpresa, @PROCOD, @DescricaoPro, @CodMarca, @MarcaNome
	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA DE PREÇOS

	If OBJECT_ID ('tempdb.dbo.#TBS031') IS NOT NULL
		DROP TABLE #TBS031;

	SELECT 
		TDPPROCOD,
		convert(decimal (12,2),
		CASE WHEN TDPVALPROI<=GETDATE() AND TDPVALPROF >= GETDATE() AND TDPPROLOJ = 'S' 
			THEN ROUND(TDPPREPRO1, 2) 
			ELSE ROUND(TDPPRELOJ1, 2) 
		END) AS PRECO1,

		CONVERT(decimal (12,2),
		CASE WHEN TDPVALPROI<=GETDATE() AND TDPVALPROF >= GETDATE() AND TDPPROLOJ = 'S'
			THEN ROUND(TDPPREPRO2, 2)
			ELSE ROUND(TDPPRELOJ2, 2)
		END) AS PRECO2 ,

		CONVERT(decimal (12,2),
		CASE WHEN TDPVALPROI<=GETDATE() AND TDPVALPROF >= GETDATE() AND TDPPROLOJ = 'S'
			THEN ROUND(TDPPREPRO3, 2)
			ELSE ROUND(TDPPRELOJ3, 2)
		END) AS PRECO3,

		CONVERT(decimal (12,2),
		CASE WHEN TDPVALPROI<=GETDATE() AND TDPVALPROF >= GETDATE() AND TDPPROLOJ = 'S'
			THEN ROUND(TDPPREPRO4, 2)
			ELSE ROUND(TDPPRELOJ4, 2)
		END) AS PRECO4

	INTO #TBS031 FROM TBS031 (NOLOCK)

	WHERE 
		TDPEMPCOD = @empresaTBS031 AND
		TDPPROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #T) AND
		((CONVERT(CHAR(10),TDPDATATU,103)) BETWEEN @data_DE AND @data_ATE OR
		(CONVERT(CHAR(10),TDPVALPROF + 1,103)) BETWEEN @data_DE AND @data_ATE)	
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA DE SALDO 

	If OBJECT_ID ('tempdb.dbo.#TBS032') IS NOT NULL
		DROP TABLE #TBS032;	

	SELECT 
		PROCOD 
	INTO #TBS032 FROM TBS032 (NOLOCK)

	WHERE 
		PROEMPCOD = @empresaTBS010 AND
		ESTLOC = @LocalLoja AND
		PROCOD COLLATE DATABASE_DEFAULT	IN (SELECT PROCOD FROM #T) AND
		PROCOD COLLATE DATABASE_DEFAULT	IN (SELECT TDPPROCOD FROM #TBS031) AND
		ESTQTDATU - ESTQTDRES > @Disponivel
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela TBS010 para filtros

	If OBJECT_ID ('tempdb.dbo.#TBS010') IS NOT NULL
		DROP TABLE #TBS010;

	SELECT TOP 0
		PROSTATUS , 
		PROCOD, 
		PRODES, 
		MARNOM, 
		PROUM1,
		PROUM2,
		PROUM3,
		PROUM4,
		PROUMV,
		PROUM1QTD,
		PROUM2QTD,
		PROUM3QTD,
		PROUM4QTD,
		RTRIM((SELECT UNIDES FROM TBS011 D (NOLOCK) WHERE A.PROUM1 = D.UNICOD)) as UNIDES, 
		A.PROSETLOJ1, 
		A.PROSETLOJ2,
		A.GRUCOD, 
		isnull((select top 1 rtrim(ltrim(GRUDES)) from TBS012 B (nolock) where A.GRUCOD = B.GRUCOD order by B.GRUEMPCOD, B.GRUCOD),'') as GRUDES
	INTO #TBS010 FROM TBS010 A (NOLOCK)

	SET @cmdSQL	= N'
	INSERT INTO #TBS010

	SELECT  
		A.PROSTATUS , 
		RTRIM(LTRIM(A.PROCOD)) AS PROCOD, 
		RTRIM(LTRIM(A.PRODES)) AS PRODES, 
		RTRIM(LTRIM(A.MARNOM)) AS MARNOM, 
		PROUM1,
		PROUM2,
		PROUM3,
		PROUM4,
		PROUMV,
		PROUM1QTD,
		PROUM2QTD,
		PROUM3QTD,
		PROUM4QTD,
		RTRIM((SELECT UNIDES FROM TBS011 D (NOLOCK) WHERE A.PROUM1 = D.UNICOD)) as UNIDES, 
		A.PROSETLOJ1, 
		A.PROSETLOJ2,
		A.GRUCOD, 
		isnull((select top 1 rtrim(ltrim(GRUDES)) from TBS012 B (nolock) where A.GRUCOD = B.GRUCOD order by B.GRUEMPCOD, B.GRUCOD), '''') as GRUDES

		FROM TBS010 A (NOLOCK)
	WHERE 
	PROEMPCOD = @empresaTBS010 AND
	A.PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #T) AND 
	A.PROCOD COLLATE DATABASE_DEFAULT IN (SELECT TDPPROCOD FROM #TBS031) AND 
	A.PROCOD COLLATE DATABASE_DEFAULT IN (SELECT PROCOD FROM #TBS032) AND 
	A.PROSTATUS IN(''' + RTRIM(LTRIM(@STATUS)) + ''')
	'				
	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS010 int'

	EXEC sp_executesql @cmdSQL, @ParmDef, @empresaTBS010
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	If OBJECT_ID ('tempdb.dbo.#tbs') IS NOT NULL
		drop table #tbs

	SELECT  
	rank() OVER (ORDER BY A.PROCOD) AS [RANKS],
	A.PROSTATUS AS STS, 
	RTRIM(LTRIM(A.PROCOD)) AS CÓDIGO, 
	RTRIM(LTRIM(A.PRODES)) AS DESCRIÇÃO, 
	RTRIM(LTRIM(A.MARNOM)) AS MARCA, 

	'*'+RTRIM(A.PROCOD)+'*'  AS CODBAR1,

	CASE WHEN PROUM2QTD > 0 
		THEN '*'+RTRIM(LTRIM(A.PROCOD))+'-2*' 
		ELSE '' 
	END AS CODBAR2,
		
	PRECO1,
	round(PRECO2 * round(PROUM2QTD, 2), 2) AS PRECO2,
	round(PRECO3 * round(PROUM3QTD, 2), 2) AS PRECO3,
	round(PRECO4 * round(PROUM4QTD, 2), 2) AS PRECO4,

	PRECO2 AS PRECO2UNI,
	PRECO3 AS PRECO3UNI,
	PRECO4 AS PRECO4UNI,

	CASE WHEN PROUM1QTD = 1
		THEN RTRIM((SELECT UNIDES FROM TBS011 D (NOLOCK) WHERE A.PROUM1 = D.UNICOD))   
		ELSE
			CASE WHEN PROUM1QTD > 1 
			THEN rtrim(PROUM1) + ' C/' + rtrim(CAST(PROUM1QTD AS DECIMAL(10,0))) +''+ RTRIM(PROUMV) 
			ELSE '' 
		END 
	END  as UN1,
	'R$' sifra,

	CASE WHEN PROUM2QTD > 0 and PRECO2 > 0
		THEN rtrim(PROUM2) + ' C/' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1) 
		ELSE '' 
	END  as UN2,

	CASE WHEN PROUM3QTD > 0 and PRECO3 > 0
		THEN rtrim(PROUM3) + ' C/' + rtrim(CAST(PROUM3QTD / PROUM2QTD AS DECIMAL(10,0)))+''+ rtrim(PROUM2) + ' C/' + rtrim(CAST(PROUM2QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1)
		ELSE '' 
	END  as UN3,

	CASE WHEN PROUM4QTD > 0 and PRECO4 > 0
		THEN rtrim(PROUM4) + ' C/' + rtrim(CAST(PROUM4QTD / PROUM3QTD AS DECIMAL(10,0)))+''+ rtrim(PROUM3) + ' C/' + rtrim(CAST(PROUM3QTD AS DECIMAL(10,0)))+''+ RTRIM(PROUM1)
		ELSE '' 
	END  as UN4,

	0 AS PP,

	A.PROUM1 AS UNpp,

	rtrim(ltrim(A.PROSETLOJ1)) AS PROSETLOJ1, 
	rtrim(ltrim(A.PROSETLOJ2)) AS PROSETLOJ2,

	A.GRUCOD, 
	A.GRUDES

	into #tbs

	FROM #TBS010 A (NOLOCK)
	INNER	JOIN #TBS031 B (NOLOCK) ON A.PROCOD = B.TDPPROCOD 
	INNER	JOIN #TBS032 D (NOLOCK) ON A.PROCOD = D.PROCOD 
					
	ORDER BY [RANKS]
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	IF OBJECT_ID ('tempdb.dbo.#E') IS NOT NULL
		drop table #E	

	CREATE TABLE #E (
		RANKS INT,
		STS CHAR (1),
		CÓDIGO CHAR (15),
		DESCRIÇÃO CHAR(60),
		MARCA CHAR(60),
		CODBAR1 CHAR(17),
		CODBAR2 CHAR(19),

		PRECO1 DECIMAL(10,2),
		PRECO2 DECIMAL(10,2),
		PRECO3 DECIMAL(10,2),
		PRECO4 DECIMAL(10,2),

		PRECO2UNI DECIMAL(10,2),
		PRECO3UNI DECIMAL(10,2),
		PRECO4UNI DECIMAL(10,2),

		UN1 CHAR (15),
		sifra CHAR (2),
		UN2 CHAR (15),
		UN3 VARCHAR (25),
		UN4 VARCHAR (60),

		PP INT,
		UNpp CHAR(2),
		SETLOJ1 VARCHAR(3),
		SETLOJ2 VARCHAR(3),
		codigoGrupo int,
		descricaoGrupo char(20)
		)

	declare @i INT

	SET @i = 1

	WHILE (@i <= @QtdEtiquetas)
	BEGIN
		INSERT INTO #E

		SELECT * from #tbs

		SET @i = @i + 1
	END 

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT ROW_NUMBER ( ) OVER (ORDER BY CÓDIGO) AS [RANK],* FROM #E
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
End