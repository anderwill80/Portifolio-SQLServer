/*
====================================================================================================================================================================================
WREL060 - Saldo negativo
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
13/01/2025 - WILLIAM
	- Conversao do script SQL para StoredProcedure;
	- Inclusao do @empcod nos parametros de entrada da SP;	
	- Inclusao de filtros nas tabelas pela empresa, utilizando o par�metro recebido via menu do Integros(@empcod), juntamente com a SP "usp_GetCodigoEmpresaTabela";
************************************************************************************************************************************************************************************
*/
CREATE PROCEDURE [dbo].[usp_RS_SaldoNegativo]
--alter PROCEDURE [dbo].[usp_RS_SaldoNegativo]
	@empcod smallint,
	@estoque varchar(100),
	@grupo varchar(200)
AS
BEGIN
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	DECLARE @codigoEmpresa smallint, @empresaTBS010 smallint, @empresaTBS012 smallint, @empresaTBS032 smallint, @empresaTBS034 smallint,
			@Estoques varchar(100), @Grupos varchar(200);


-- Desativando a detec��o de par�metros(Parameter Sniffing)
	SET @codigoEmpresa = @empcod;
	SET @Estoques = @estoque;
	SET @Grupos = @grupo;

-- Uso da funcao split, para as clausulas IN()
	-- Locais de estoque
	If object_id('TempDB.dbo.#LOCAIS') is not null
		DROP TABLE #LOCAIS;
	select 
		elemento as estloc
	Into #LOCAIS
	From fSplit(@Estoques, ',');
	-- Grupo de produtos
	If object_id('TempDB.dbo.#GRUPOSPRO') is not null
		DROP TABLE #GRUPOSPRO;
	select 
		elemento as grupo
	Into #GRUPOSPRO
	From fSplit(@Grupos, ',');
	If @Grupos = ''
		DELETE #GRUPOSPRO;

	-- Verificar se a tabela compartilhada ou exclusiva
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS010', @empresaTBS010 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS012', @empresaTBS012 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS032', @empresaTBS032 output;
	exec dbo.usp_GetCodigoEmpresaTabela @codigoEmpresa, 'TBS034', @empresaTBS034 output;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela final

	SELECT       
		RTRIM(C.LESDES) AS 'Estoque', 
		RTRIM(B.PROSTATUS) AS 'Status',
		RTRIM(A.PROCOD) AS 'Codigo', 
		RTRIM(B.PRODES) AS 'Descricao',
		RTRIM(LTRIM(STR(B.MARCOD) + ' - ' + B.MARNOM)) AS 'Nome Marca', 
		RTRIM(B.PROUM1) AS 'UN1', A.ESTQTDATU AS 'SALDO', 
		ISNULL(RTRIM(D.GRUDES), 'SEM GRUPO') + ' (' + ISNULL(LTRIM(STR(B.GRUCOD, 3)), 0) + ')' AS 'grupo'

	FROM TBS032 AS A WITH (NOLOCK) 
	LEFT OUTER JOIN  TBS010 AS B WITH (NOLOCK) ON B.PROEMPCOD = @empresaTBS010 AND A.PROCOD = B.PROCOD 
	LEFT OUTER JOIN  TBS034 AS C WITH (NOLOCK) ON LESEMPCOD = @empresaTBS034 AND A.ESTLOC = C.LESCOD 
	LEFT OUTER JOIN	 TBS012 AS D WITH (NOLOCK) ON D.GRUEMPCOD = @empresaTBS012 AND B.GRUCOD = D.GRUCOD

	WHERE
	A.PROEMPCOD = @empresaTBS010 AND
	(A.ESTLOC IN (SELECT estloc FROM #LOCAIS)) AND
	(A.ESTQTDATU < 0) AND 
	(B.GRUCOD IN (SELECT grupo FROM #GRUPOSPRO))
END