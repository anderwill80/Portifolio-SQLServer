/*
====================================================================================================================================================================================
Script do Report Server					Boleto
====================================================================================================================================================================================
										Histórico de alterações
====================================================================================================================================================================================
Data		Por							Descrição
**********	********************		********************************************************************************************************************************************
23/05/2024	ANDERSON WILLIAM			- Conversão para Stored procedure
										- Uso de querys dinâmicas utilizando a "sp_executesql" para executar comando sql com parâmetros
										- Uso da "usp_GetCodigoEmpresaTabela" em vez de "sp_GetCodigoEmpresaTabela", 
										  SQL deixa de verificar SP no BD Master, buscando direto no SIBD
										- Inclusão de filtro pela empresa da tabela, irá atender empresas como ex.: MRE Ferramentas
************************************************************************************************************************************************************************************
*/
alter proc [dbo].usp_RS_Boleto(
--create proc [dbo].usp_RS_Boleto(
	@empcod smallint,
	@registro int
)
as

begin

	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Declarações das variaveis locais
	declare	@empresaTMP026 smallint,
			@empresa smallint, @T26_REGISTRO int			
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Atribuições para desabilitar o "Parameter Sniffing" do SQL
	SET @empresa = @empcod
	SET @T26_REGISTRO = @registro
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela é compartilhada ou exclusiva(Usando a SP com prefixo renomeada para "usp_...")

	EXEC dbo.usp_GetCodigoEmpresaTabela @empresa, 'TMP026', @empresaTMP026 output;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Tabela com registros de boletos

	SELECT
	*
	FROM TMP026 WITH (NOLOCK)

	WHERE (T26_EMPRESA = @empresaTMP026) AND (T26_REGISTRO = @T26_REGISTRO)

	ORDER BY T26_EMPRESA, T26_REGISTRO, T26_NOSNUM

End