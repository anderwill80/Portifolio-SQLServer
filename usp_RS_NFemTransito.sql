/*
====================================================================================================================================================================================
Script do Report Server					Notas fiscais em trânsito
====================================================================================================================================================================================
										Historico de alteracoes
====================================================================================================================================================================================
Data		Por							Descricao
**********	********************		********************************************************************************************************************************************
10/12/2024	ANDERSON WILLIAM			- Conversao para Stored procedure
************************************************************************************************************************************************************************************
*/
alter proc [dbo].usp_RS_NFemTransito(
--create proc [dbo].usp_RS_NFemTransito(
	@empcod int,
	@DATADE datetime = null,
	@DATAATE datetime = null,
	@EMPRESA VARCHAR(200)
)
as
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- variaveis internas do reporting services

	DECLARE @empresaTBS059 SMALLINT, @cnpj_empresa_local VARCHAR(30), @emp SMALLINT, @data_DE DATETIME, @data_ATE DATETIME, @cEmpresa VARCHAR(200),
			@dataSource varchar(35), @verificaLink int, @geraDado1 varchar(max), @geraDado2 varchar(max), @geraDado3 varchar(max)
	
	SET @emp = @empcod
	SET @data_DE = (select isnull(@DATADE, '01/01/1753'))
	SET @data_ATE = (select isnull(@DATAATE, GETDATE()))
	SET @cEmpresa = @EMPRESA

	-- Obtem o CNPJ da empresa que está rodando o relatório
	SET @cnpj_empresa_local = (SELECT RTRIM(LTRIM(EMPCGC)) AS EMPCGC FROM TBS023 (NOLOCK) WHERE EMPCOD = @emp)	

	-- Verificar se a tabela compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	exec dbo.usp_GetCodigoEmpresaTabela @emp, 'TBS059', @empresaTBS059 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------		
	-- cria tabela para receber os dados das empresas	

	IF OBJECT_ID('tempdb.dbo.#Saida') IS NOT NULL 
		DROP TABLE #Saida;
	
	create table #Saida (
	EMPRESA 	VARCHAR(20) COLLATE DATABASE_DEFAULT, 
	ENFNUM 		INT, 
	ENFDATEMI 	DATETIME, 
	SNESER 		INT, 
	ENFCHAACE 	VARCHAR(50) COLLATE DATABASE_DEFAULT,
	ENFVALTOT 	DECIMAL(10,4) )

	-- cria tabela de notas devolvidads 	
	IF OBJECT_ID('tempdb.dbo.#NotaDevolvida') IS NOT NULL 
		DROP TABLE #NotaDevolvida;
	
	create table #NotaDevolvida (
	NFECHAACE 	VARCHAR(60) COLLATE DATABASE_DEFAULT, 
	NFENFRCHA 	VARCHAR(60) COLLATE DATABASE_DEFAULT)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TANBY MATRIZ     

	if @cnpj_empresa_local != '65069593000198' AND PATINDEX('%Tanby Matriz%', @cEmpresa) > 0
	BEGIN
    	set @dataSource = (select data_source from sys.servers where name='nd')

    	exec VerificaLink3 @dataSource, @verificaLink output	

		IF @verificaLink = 0
		BEGIN
			INSERT INTO #Saida
	
			SELECT TOP 1
			'Tanby Matriz' AS EMPRESA,
			0 AS ENFNUM, 
			'17530101' AS ENFDATEMI,
			0 AS SNESER, 
			'Tanby Matriz esta com o link fora!' AS ENFCHAACE,
			0 AS ENFVALTOT
	
			FROM TBS001
		END
		ELSE
		BEGIN  
			set @geraDado1 = '
				INSERT INTO #Saida	
			
				SELECT
				''Tanby Matriz'' AS EMPRESA,
				ENFNUM, 
				ENFDATEMI,
				SNESER, 
				ENFCHAACE,
				ENFVALTOT

				FROM nd.SIBD.dbo.TBS080 A 

				WHERE
				ENFCNPJCPF = ''' + @cnpj_empresa_local + ''' AND 
				ENFSIT = 6 AND 
				ENFTIPDOC = 1 AND 
				ENFDATEMI BETWEEN '''+convert(char(8), @data_DE, 112)+''' AND '''+convert(char(8), @data_ATE, 112)+'''
				'

				set @geraDado2 = '
				IF (SELECT COUNT(*) FROM  nd.SIBD.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0
				BEGIN 
					-- se achar alguma refencia, verificar qual a nota e se a mesma est� autorizada (join na TBS059, pegar a chave e verificar na TBS080)			

					INSERT INTO #NotaDevolvida	

					SELECT 
					B.NFECHAACE,
					A.NFENFRCHA

					FROM nd.SIBD.dbo.TBS0596 A
					INNER JOIN nd.SIBD.dbo.TBS059 B ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFETIP = B.NFETIP AND A.NFENUM = B.NFENUM AND A.NFECOD = B.NFECOD AND A.SEREMPCOD = A.SEREMPCOD AND A.SERCOD = B.SERCOD
					INNER JOIN nd.SIBD.dbo.TBS080 C ON B.NFECHAACE = C.ENFCHAACE AND C.ENFTIPDOC = 0 AND C.ENFSIT = 6

					WHERE 
					NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)	
				END
				'

				set @geraDado3 = '
				IF (SELECT COUNT(*) FROM  nd.SIBD.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0

				begin
					-- se estiver autorizada, retirar ela da lista que ira compara com as entradas da base (dar um delete na tabela, com a chave de saida como condi��o)

					DELETE #Saida
					WHERE ENFCHAACE collate database_default IN (SELECT NFENFRCHA FROM #NotaDevolvida)

				END
				'
				Exec(@geraDado1)
				Exec(@geraDado2)
				Exec(@geraDado3)
		END
	END
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TANBY CD    

	if @cnpj_empresa_local != '65069593000350' AND PATINDEX('%Tanby CD%', @cEmpresa) > 0
	BEGIN
    	set @dataSource = (select data_source from sys.servers where name='cd')

    	exec VerificaLink3 @dataSource, @verificaLink output	

		IF @verificaLink = 0
		BEGIN
			INSERT INTO #Saida
	
			SELECT TOP 1
			'Tanby CD' AS EMPRESA,
			0 AS ENFNUM, 
			'17530101' AS ENFDATEMI,
			0 AS SNESER, 
			'Tanby CD esta com o link fora!' AS ENFCHAACE,
			0 AS ENFVALTOT
	
			FROM TBS001
		END
		ELSE
		BEGIN  
			set @geraDado1 = '
				INSERT INTO #Saida	
			
				SELECT
				''Tanby CD'' AS EMPRESA,
				ENFNUM, 
				ENFDATEMI,
				SNESER, 
				ENFCHAACE,
				ENFVALTOT

				FROM cd.SIBD.dbo.TBS080 A 

				WHERE
				ENFCNPJCPF = ''' + @cnpj_empresa_local + ''' AND 
				ENFSIT = 6 AND 
				ENFTIPDOC = 1 AND 
				ENFDATEMI BETWEEN '''+convert(char(8), @data_DE, 112)+''' AND '''+convert(char(8), @data_ATE, 112)+'''
				'

				set @geraDado2 = '
				IF (SELECT COUNT(*) FROM  cd.SIBD.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0
				BEGIN 
					-- se achar alguma refencia, verificar qual a nota e se a mesma est� autorizada (join na TBS059, pegar a chave e verificar na TBS080)			

					INSERT INTO #NotaDevolvida	

					SELECT 
					B.NFECHAACE,
					A.NFENFRCHA

					FROM cd.SIBD.dbo.TBS0596 A
					INNER JOIN cd.SIBD.dbo.TBS059 B ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFETIP = B.NFETIP AND A.NFENUM = B.NFENUM AND A.NFECOD = B.NFECOD AND A.SEREMPCOD = A.SEREMPCOD AND A.SERCOD = B.SERCOD
					INNER JOIN cd.SIBD.dbo.TBS080 C ON B.NFECHAACE = C.ENFCHAACE AND C.ENFTIPDOC = 0 AND C.ENFSIT = 6

					WHERE 
					NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)	
				END
				'
				set @geraDado3 = '
				IF (SELECT COUNT(*) FROM  cd.SIBD.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0

				begin
					-- se estiver autorizada, retirar ela da lista que ira compara com as entradas da base (dar um delete na tabela, com a chave de saida como condi��o)

					DELETE #Saida
					WHERE ENFCHAACE collate database_default IN (SELECT NFENFRCHA FROM #NotaDevolvida)

				END
				'
				Exec(@geraDado1)
				Exec(@geraDado2)
				Exec(@geraDado3)
		END
	END
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TANBY TAUBATE    

	if @cnpj_empresa_local != '65069593000279' AND PATINDEX('%Tanby Taubate%', @cEmpresa) > 0
	BEGIN
    	set @dataSource = (select data_source from sys.servers where name='tt')

    	exec VerificaLink3 @dataSource, @verificaLink output	

		IF @verificaLink = 0
		BEGIN
			INSERT INTO #Saida
	
			SELECT TOP 1
			'Tanby Taubate' AS EMPRESA,
			0 AS ENFNUM, 
			'17530101' AS ENFDATEMI,
			0 AS SNESER, 
			'Tanby Taubate esta com o link fora!' AS ENFCHAACE,
			0 AS ENFVALTOT
	
			FROM TBS001
		END
		ELSE
		BEGIN  
			set @geraDado1 = '
				INSERT INTO #Saida	
			
				SELECT
				''Tanby Taubate'' AS EMPRESA,
				ENFNUM, 
				ENFDATEMI,
				SNESER, 
				ENFCHAACE,
				ENFVALTOT

				FROM tt.SIBD.dbo.TBS080 A 

				WHERE
				ENFCNPJCPF = ''' + @cnpj_empresa_local + ''' AND 
				ENFSIT = 6 AND 
				ENFTIPDOC = 1 AND 
				ENFDATEMI BETWEEN '''+convert(char(8), @data_DE, 112)+''' AND '''+convert(char(8), @data_ATE, 112)+'''
				'

			set @geraDado2 = '
				IF (SELECT COUNT(*) FROM  tt.SIBD.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0
				BEGIN 
					-- se achar alguma refencia, verificar qual a nota e se a mesma est� autorizada (join na TBS059, pegar a chave e verificar na TBS080)			

					INSERT INTO #NotaDevolvida	

					SELECT 
					B.NFECHAACE,
					A.NFENFRCHA

					FROM tt.SIBD.dbo.TBS0596 A
					INNER JOIN tt.SIBD.dbo.TBS059 B ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFETIP = B.NFETIP AND A.NFENUM = B.NFENUM AND A.NFECOD = B.NFECOD AND A.SEREMPCOD = A.SEREMPCOD AND A.SERCOD = B.SERCOD
					INNER JOIN tt.SIBD.dbo.TBS080 C ON B.NFECHAACE = C.ENFCHAACE AND C.ENFTIPDOC = 0 AND C.ENFSIT = 6

					WHERE 
					NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)	
				END
				'
			set @geraDado3 = '
				IF (SELECT COUNT(*) FROM  tt.SIBD.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0

				begin
					-- se estiver autorizada, retirar ela da lista que ira compara com as entradas da base (dar um delete na tabela, com a chave de saida como condi��o)

					DELETE #Saida
					WHERE ENFCHAACE collate database_default IN (SELECT NFENFRCHA FROM #NotaDevolvida)

				END
				'
				Exec(@geraDado1)
				Exec(@geraDado2)
				Exec(@geraDado3)
		END
	END
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- PAPELYNA

	if @cnpj_empresa_local != '44125185000136' AND PATINDEX('%Papelyna%', @cEmpresa) > 0
	BEGIN
    	set @dataSource = (select data_source from sys.servers where name = 'py')

    	exec VerificaLink3 @dataSource, @verificaLink output	

		IF @verificaLink = 0
		BEGIN
			INSERT INTO #Saida
	
			SELECT TOP 1
			'Papelyna' AS EMPRESA,
			0 AS ENFNUM, 
			'17530101' AS ENFDATEMI,
			0 AS SNESER, 
			'Papelyna esta com o link fora!' AS ENFCHAACE,
			0 AS ENFVALTOT
	
			FROM TBS001
		END
		ELSE
		BEGIN  
			set @geraDado1 = '
				INSERT INTO #Saida	
			
				SELECT
				''Papelyna'' AS EMPRESA,
				ENFNUM, 
				ENFDATEMI,
				SNESER, 
				ENFCHAACE,
				ENFVALTOT

				FROM py.SIBD.dbo.TBS080 A 

				WHERE
				ENFCNPJCPF = ''' + @cnpj_empresa_local + ''' AND 
				ENFSIT = 6 AND 
				ENFTIPDOC = 1 AND 
				ENFDATEMI BETWEEN '''+convert(char(8), @data_DE, 112)+''' AND '''+convert(char(8), @data_ATE, 112)+'''
				'

			set @geraDado2 = '
				IF (SELECT COUNT(*) FROM  py.SIBD.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0
				BEGIN 
					-- se achar alguma refencia, verificar qual a nota e se a mesma est� autorizada (join na TBS059, pegar a chave e verificar na TBS080)			

					INSERT INTO #NotaDevolvida	

					SELECT 
					B.NFECHAACE,
					A.NFENFRCHA

					FROM py.SIBD.dbo.TBS0596 A
					INNER JOIN py.SIBD.dbo.TBS059 B ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFETIP = B.NFETIP AND A.NFENUM = B.NFENUM AND A.NFECOD = B.NFECOD AND A.SEREMPCOD = A.SEREMPCOD AND A.SERCOD = B.SERCOD
					INNER JOIN py.SIBD.dbo.TBS080 C ON B.NFECHAACE = C.ENFCHAACE AND C.ENFTIPDOC = 0 AND C.ENFSIT = 6

					WHERE 
					NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)	
				END
				'
			set @geraDado3 = '
				IF (SELECT COUNT(*) FROM  py.SIBD.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0

				begin
					-- se estiver autorizada, retirar ela da lista que ira compara com as entradas da base (dar um delete na tabela, com a chave de saida como condi��o)

					DELETE #Saida
					WHERE ENFCHAACE collate database_default IN (SELECT NFENFRCHA FROM #NotaDevolvida)

				END
				'
				Exec(@geraDado1)
				Exec(@geraDado2)
				Exec(@geraDado3)
		END
	END
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- MISASPEL   

	if @cnpj_empresa_local != '52080207000117' AND PATINDEX('%Misaspel%', @cEmpresa) > 0
	BEGIN
    	set @dataSource = (select data_source from sys.servers where name = 'py')

    	exec VerificaLink3 @dataSource, @verificaLink output	

		IF @verificaLink = 0
		BEGIN
			INSERT INTO #Saida
	
			SELECT TOP 1
			'Misaspel' AS EMPRESA,
			0 AS ENFNUM, 
			'17530101' AS ENFDATEMI,
			0 AS SNESER, 
			'Misaspel esta com o link fora!' AS ENFCHAACE,
			0 AS ENFVALTOT
	
			FROM TBS001
		END
		ELSE
		BEGIN  
			set @geraDado1 = '
				INSERT INTO #Saida	
			
				SELECT
				''Misaspel'' AS EMPRESA,
				ENFNUM, 
				ENFDATEMI,
				SNESER, 
				ENFCHAACE,
				ENFVALTOT

				FROM py.SIBD3.dbo.TBS080 A 

				WHERE
				ENFCNPJCPF = ''' + @cnpj_empresa_local + ''' AND 
				ENFSIT = 6 AND 
				ENFTIPDOC = 1 AND 
				ENFDATEMI BETWEEN '''+convert(char(8), @data_DE, 112)+''' AND '''+convert(char(8), @data_ATE, 112)+'''
				'

			set @geraDado2 = '
				IF (SELECT COUNT(*) FROM  py.SIBD3.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0
				BEGIN 
					-- se achar alguma refencia, verificar qual a nota e se a mesma est� autorizada (join na TBS059, pegar a chave e verificar na TBS080)			

					INSERT INTO #NotaDevolvida	

					SELECT 
					B.NFECHAACE,
					A.NFENFRCHA

					FROM py.SIBD3.dbo.TBS0596 A
					INNER JOIN py.SIBD3.dbo.TBS059 B ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFETIP = B.NFETIP AND A.NFENUM = B.NFENUM AND A.NFECOD = B.NFECOD AND A.SEREMPCOD = A.SEREMPCOD AND A.SERCOD = B.SERCOD
					INNER JOIN py.SIBD3.dbo.TBS080 C ON B.NFECHAACE = C.ENFCHAACE AND C.ENFTIPDOC = 0 AND C.ENFSIT = 6

					WHERE 
					NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)	
				END
				'
			set @geraDado3 = '
				IF (SELECT COUNT(*) FROM  py.SIBD3.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0

				begin
					-- se estiver autorizada, retirar ela da lista que ira compara com as entradas da base (dar um delete na tabela, com a chave de saida como condi��o)

					DELETE #Saida
					WHERE ENFCHAACE collate database_default IN (SELECT NFENFRCHA FROM #NotaDevolvida)

				END
				'
				Exec(@geraDado1)
				Exec(@geraDado2)
				Exec(@geraDado3)
		END
	END
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- BEST BAG

	if @cnpj_empresa_local != '05118717000156' AND PATINDEX('%Best Bag%', @cEmpresa) > 0
	BEGIN
    	set @dataSource = (select data_source from sys.servers where name = 'bb2')

    	exec VerificaLink3 @dataSource, @verificaLink output	

		IF @verificaLink = 0
		BEGIN
			INSERT INTO #Saida
	
			SELECT TOP 1
			'Best Bag' AS EMPRESA,
			0 AS ENFNUM, 
			'17530101' AS ENFDATEMI,
			0 AS SNESER, 
			'Best Bag esta com o link fora!' AS ENFCHAACE,
			0 AS ENFVALTOT
	
			FROM TBS001
		END
		ELSE
		BEGIN  
			set @geraDado1 = '
				INSERT INTO #Saida	
			
				SELECT
				''Best Bag'' AS EMPRESA,
				ENFNUM, 
				ENFDATEMI,
				SNESER, 
				ENFCHAACE,
				ENFVALTOT

				FROM bb2.SIBD2.dbo.TBS080 A 

				WHERE
				ENFCNPJCPF = ''' + @cnpj_empresa_local + ''' AND 
				ENFSIT = 6 AND 
				ENFTIPDOC = 1 AND 
				ENFDATEMI BETWEEN '''+convert(char(8), @data_DE, 112)+''' AND '''+convert(char(8), @data_ATE, 112)+'''
				'

			set @geraDado2 = '
				IF (SELECT COUNT(*) FROM  bb2.SIBD2.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0
				BEGIN 
					-- se achar alguma refencia, verificar qual a nota e se a mesma est� autorizada (join na TBS059, pegar a chave e verificar na TBS080)			

					INSERT INTO #NotaDevolvida	

					SELECT 
					B.NFECHAACE,
					A.NFENFRCHA

					FROM bb2.SIBD2.dbo.TBS0596 A
					INNER JOIN bb2.SIBD2.dbo.TBS059 B ON A.NFEEMPCOD = B.NFEEMPCOD AND A.NFETIP = B.NFETIP AND A.NFENUM = B.NFENUM AND A.NFECOD = B.NFECOD AND A.SEREMPCOD = A.SEREMPCOD AND A.SERCOD = B.SERCOD
					INNER JOIN bb2.SIBD2.dbo.TBS080 C ON B.NFECHAACE = C.ENFCHAACE AND C.ENFTIPDOC = 0 AND C.ENFSIT = 6

					WHERE 
					NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)	
				END
				'
			set @geraDado3 = '
				IF (SELECT COUNT(*) FROM  bb2.SIBD2.dbo.TBS0596 WHERE NFENFRCHA collate database_default IN (SELECT ENFCHAACE FROM #Saida)) > 0

				begin
					-- se estiver autorizada, retirar ela da lista que ira compara com as entradas da base (dar um delete na tabela, com a chave de saida como condi��o)

					DELETE #Saida
					WHERE ENFCHAACE collate database_default IN (SELECT NFENFRCHA FROM #NotaDevolvida)

				END
				'
				Exec(@geraDado1)
				Exec(@geraDado2)
				Exec(@geraDado3)
		END
	END

--	SELECT * FROM #Saida
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- CRIAR A BASE PARA PROCURAR OS PRODUTOS

	IF OBJECT_ID('tempdb.dbo.#BASE') IS NOT NULL 
		DROP TABLE #BASE;

	SELECT 
	NFENUM,
	NFECHAACE,
	NFEDATEFE,
	REPLACE(CONVERT(CHAR(5),B.NFEDATEMI,11),'/','') as EMISSAO	

	INTO #BASE

	FROM TBS059 B (NOLOCK)
	WHERE 
	NFEEMPCOD = @empresaTBS059 AND
	B.NFECAN <> 'S' AND 
	NFECHAACE IN (SELECT ENFCHAACE FROM #SAIDA )

--	select * from #BASE
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- PROCURAR NA BASE 

	SELECT 
	EMPRESA,
	ENFNUM, 
	SUBSTRING(CONVERT(CHAR(10),ENFDATEMI,103),4,7) AS MESSAIDA,
	ENFDATEMI,
	SNESER, 
	ENFCHAACE,
	ENFVALTOT,
	B.NFEDATEFE,
	SUBSTRING(CONVERT(CHAR(10),NFEDATEFE,103),4,7) AS MESENTRADA

	FROM #SAIDA A
	LEFT JOIN #BASE B ON ENFCHAACE = B.NFECHAACE AND A.ENFNUM = B.NFENUM

	WHERE 
	B.NFENUM IS NULL 

END