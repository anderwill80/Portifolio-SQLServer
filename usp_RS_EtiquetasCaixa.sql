/*
====================================================================================================================================================================================
Script do Report Server					Etiquetas de Loja
====================================================================================================================================================================================
										Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
24/06/2024	ANDERSON WILLIAM			- Busca pelos códigos de barras da tabela TBS0103, em vez dos atributos da TBS010, não usados mais;
										- Conversão para Stored procedure
										- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
										- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", 
										  SQL deixa de verificar SP no BD Master, buscando direto no SIBD
										- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas
************************************************************************************************************************************************************************************
*/
alter proc [dbo].usp_RS_EtiquetasCaixa(
--create proc [dbo].usp_RS_EtiquetasCaixa(
	@empcod smallint,
	@COD  varchar(8000),
	@A int
	)
as

begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais

	declare	@empresaTBS010 int,
			@Query nvarchar (MAX), @ParmDef nvarchar (500),
			@empresa smallint, @PROCOD varchar(8000), @BARRAS1 varchar(8000), @QtdEtiquetas int			
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribuições das variáveis

	SET @empresa = @empcod
	SET @QtdEtiquetas = @A

	-- formata parâmetros para os filtros IN(). Ex.: ReportServer envia como: "E,S", precisa ficar " 'E','S' "
	SET @BARRAS1		= REPLACE(REPLACE(@COD, ',', ''','''), ' ', '')
	SET @PROCOD			= @COD

	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	exec dbo.usp_GetCodigoEmpresaTabela @empresa, 'TBS010', @empresaTBS010 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Filtra produto pelo código ou código de barras, se vazio filtra todos os código da TBS010

	If object_id('TempDB.dbo.#T') is not null
			drop table #T  

	Create Table #T (PROCOD CHAR(15))

	IF @PROCOD <> ''
	Begin				
		Set @Query = N'
		INSERT INTO #T

		SELECT RTRIM(PROCOD) PROCOD
		FROM TBS010 (NOLOCK) 				

		WHERE
		PROEMPCOD	= @empresaTBS010 AND
		PROCOD		IN ('''+rtrim(ltrim(@BARRAS1))+''')'
			
		Set @Query += N'
		Union
			
		SELECT distinct RTRIM(LTRIM(CBPPROCOD)) PROCOD 
		FROM TBS0103 (NOLOCK) 

		WHERE 
		CBPEMP		= @empresaTBS010 AND
		CBPCODBAR	IN ('''+rtrim(ltrim(@BARRAS1))+''')
		'
	End
	Else
	Begin
		-- Se produto vazio, filtra todos...
		Set @Query = N'
		INSERT INTO #T

		SELECT RTRIM(PROCOD) PROCOD
		FROM TBS010 (NOLOCK) 				

		WHERE
		PROEMPCOD	= @empresaTBS010'			
	End

	--SELECT @Query		

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS010 int'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS010
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- TABELA DE ETIQUETAS

	IF OBJECT_ID ('TempDB.dbo.#ET') is not null
		drop table #ET

	declare  @i INT

	SET @i = 1

	SELECT TOP 0
	RTRIM(LTRIM(A.PROCOD)) AS CÓDIGO, 
	RTRIM(LTRIM(A.PRODES)) AS DESCRIÇÃO, 
	RTRIM(LTRIM(A.MARNOM)) AS MARCA, 
	'*'+RTRIM(A.PROCOD)+'*'  AS CODBAR1,
	RTRIM(PROUM1) AS UN1

	INTO #ET

	FROM  TBS010 A (NOLOCK) 

	WHERE 
	A.PROEMPCOD = @empresaTBS010

	WHILE (@i <= @QtdEtiquetas)
	BEGIN
		INSERT INTO #ET
		
		SELECT  
		RTRIM(LTRIM(A.PROCOD)) AS CÓDIGO, 
		RTRIM(LTRIM(A.PRODES)) AS DESCRIÇÃO, 
		RTRIM(LTRIM(A.MARNOM)) AS MARCA, 
		'*'+RTRIM(A.PROCOD)+'*'  AS CODBAR1,
		RTRIM(PROUM1) AS UN1

		FROM TBS010 A (NOLOCK) 

		WHERE
		A.PROEMPCOD = @empresaTBS010 AND
		A.PROCOD COLLATE DATABASE_DEFAULT IN(SELECT  PROCOD FROM #T)

		SET @i = @i + 1
	END

	SELECT ROW_NUMBER ( ) OVER (ORDER BY CÓDIGO) AS [RANK],* FROM #ET
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
End