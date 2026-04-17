/*
====================================================================================================================================================================================
Script do Report Server					Contas a Receber
====================================================================================================================================================================================
										Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
06/03/2024	ANDERSON WILLIAM			- Alterado os parâmetros para receber os códigos IBGE dos municípios, já que a UF já estará pré-filtrada no Report;

05/03/2024	ANDERSON WILLIAM			- Conversão para Stored procedure;
										- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros;
										- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela",
										  SQL deixa de verificar SP no BD Master, buscando direto no SIBD;
										- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas;
										- Uso da função "fSplit" para transformar os filtros multi-valores em tabelas, para facilitar condições via cláusula "IN()";
										- Uso da função "RetiraAcento_V" para retirar os caracteres especiais e acentos que podem dar erro ao exportar para EXCEL;
										
************************************************************************************************************************************************************************************
*/
--alter proc [dbo].usp_RS_ListagemClientesMunicipio(
create proc [dbo].usp_RS_ListagemClientesMunicipio(
	@empcod int,
	@cod_cliente smallint		= 0,
	@nome_cliente varchar(60)	= '',	
	@vendedores varchar(500),
	@municipios varchar(MAX)
	)
as

begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	DECLARE	@empresaTBS002 int, @empresaTBS004 int,
			@Query nvarchar (MAX), @ParmDef nvarchar (500),

			@CLICOD int,
			@CLINOM varchar(60),			
			@vends varchar(500),
			@Muncods varchar(MAX)
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")
	EXEC dbo.usp_GetCodigoEmpresaTabela @empcod, 'TBS002', @empresaTBS002 output;


	-- Atribuições...
	SET @CLICOD		= @cod_cliente
	SET @CLINOM		= LTRIM(RTRIM(UPPER(@nome_cliente)))
	SET @vends		= @vendedores
	SET @Muncods	= @municipios

------------------------------------------------------------------------------------------------------------------------
	-- Cria a tabela final explicitamente para ficar os campos ficarem visível para o ReportServer(Visual Studio)
	If object_id('tempdb.dbo.#TBS002') is not null
		drop table #TBS002

	-- "select TOP 0..." usado para criar a estrutura da temporária #TBS002
	SELECT TOP 0 	
	A.UFESIG as UF,
	RTRIM(ISNULL(B.MUNNOM, '')) as municipio,
	RTRIM(CLIBAI) AS bairro,
	A.VENCOD as cod_vendedor,
	RTRIM(ISNULL(C.VENNOM, '')) as nome_vendedor,
	CLICOD as cod_cliente,
	rtrim(CLINOM) as nome_cliente,
	rtrim(CLICONTAT) as contato,
	rtrim(CLITEL) as fone1,
	rtrim(CLITEL2) as fone2

	INTO #TBS002

	FROM TBS002 A WITH (NOLOCK)
	LEFT JOIN TBS003 B WITH (NOLOCK) ON B.MUNCOD = A.MUNCOD
	LEFT JOIN TBS004 C WITH (NOLOCK) ON C.VENEMPCOD = A.VENEMPCOD AND C.VENCOD = A.VENCOD
	
	--SELECT * FROM #TBS002

	-- Monta a query dinâmica
	SET @Query	= N'

	INSERT INTO #TBS002

	SELECT
	A.UFESIG as UF,
	RTRIM(ISNULL(B.MUNNOM, '''')) as municipio,
	RTRIM(dbo.RetiraAcento_V(CLIBAI, 3)) AS bairro,
	A.VENCOD as cod_vendedor,
	RTRIM(ISNULL(C.VENNOM, '''')) as nome_vendedor,
	CLICOD as cod_cliente,
	UPPER(RTRIM(dbo.RetiraAcento_V(CLINOM, 3))) as nome_cliente,
	UPPER(RTRIM(dbo.RetiraAcento_V(CLICONTAT, 3))) as contato,
	RTRIM(dbo.RetiraAcento_V(CLITEL, 3)) as fone1,
	RTRIM(dbo.RetiraAcento_V(CLITEL2, 3)) as fone2	

	FROM TBS002 A WITH (NOLOCK)
	LEFT JOIN TBS003 B WITH (NOLOCK) ON B.MUNCOD = A.MUNCOD
	LEFT JOIN TBS004 C WITH (NOLOCK) ON C.VENEMPCOD = A.VENEMPCOD AND C.VENCOD = A.VENCOD

	WHERE
	CLIEMPCOD	= @empresaTBS002 AND	
	A.VENCOD	IN (' + @vends + ') AND
	A.MUNCOD	IN (' + @Muncods + ')
	'
	+
	IIf (@CLICOD = 0, '', ' AND CLICOD = @CLICOD')
	+
	IIf (@CLINOM = '', '', ' AND A.CLINOM LIKE @CLINOM')

	--SELECT @Query

	-- Executa a Query dinâminca(QD)
	SET @ParmDef = N'@empresaTBS002 int, @CLICOD int, @CLINOM varchar(60)'

	EXEC sp_executesql @Query, @ParmDef, @empresaTBS002, @CLICOD, @CLINOM
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final
	SELECT * FROM #TBS002
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
End
