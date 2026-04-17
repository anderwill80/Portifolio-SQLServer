/*
====================================================================================================================================================================================
Permite retornar o codigo da empresa, conforme o nome da tabela recebida via parametro
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
23/01/2025 - WILLIAM
	- Correcao para retornar valor 0, quando tabela nao cadastrada na TBS024, estava retornando o valor de entrada(1,2,3,etc);
15/04/2024 - WILLIAM
	- Atribução dos parâmetros de entrada para as variaveis internas, evita o "parameter sniffing" do SQL SERVER;
************************************************************************************************************************************************************************************
*/
ALTER procedure [dbo].[usp_GetCodigoEmpresaTabela](
	@empresa int, 
	@nomeTabela varchar(10), 

	@codigoEmpresa int output
	)
As Begin 
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	SET NOCOUNT ON
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	-- Verificar se a tabela é compartilhada ou exclusiva
	declare @codempresa int, @TBSNOM varchar(10)			

	SET @codempresa = @empresa
	SET @TBSNOM = @nomeTabela
	
	-- Verificar qual o codigo da empresa da tabela selecionada	
	SET @codigoEmpresa = 0; -- deixa zero, caso nao encontre a tabela na TBS024
	SELECT 
		@codigoEmpresa = (CASE WHEN TBSMOD = 'C' THEN 0 ELSE @codempresa END)
	FROM TBS024 (NOLOCK) 
	
	WHERE 
		TBSNOM = @TBSNOM
	
	RETURN
end
GO