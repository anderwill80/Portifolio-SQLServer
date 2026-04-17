/*
====================================================================================================================================================================================
Retorna o saldo disponivel no estoque do CD
====================================================================================================================================================================================
Historico de alteracoes
====================================================================================================================================================================================
13/04/2026 WILLIAM
	- Uso da SP [usp_Check_LinkedServer] para verificar se o linkedserver 'cd' está ONLINE, caso contrário, o procedimento irá retornar o valor -9999 no parâmetro @estoqueCd;
	- Uso da SP [usp_Get_SaldoAtual_Produto] para obter o saldo atual do produto no CD;
16/10/2025 WILLIAM
	- Criação; 
====================================================================================================================================================================================
*/
--CREATE procedure [dbo].[USP_GET_SALDO_CD]
ALTER procedure [dbo].[USP_GET_SALDO_CD]
	@empresa int out,
	@codigoProduto varchar(15) output, 
	@estoqueCd decimal(12,6) output	
AS
BEGIN 
	SET NOCOUNT ON;
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	DECLARE @codigoEmpresa smallint, @PROCOD VARCHAR(15), @linkedConnected bit,
			@pEstoque DECIMAL(12,6), @pLoja DECIMAL(12,6), @pCompras DECIMAL(12,6), @pTransito DECIMAL(12,6);

-- Desativando a detecao de parametros(Parameter Sniffing)
	SET @codigoEmpresa = @empresa;
	SET @PROCOD = @codigoProduto;

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------	
	-- Verifica se linkedserver está ONLINE
	EXEC usp_Check_LinkedServer 'cd', @linkedConnected OUT;

	IF @linkedConnected = 1
	BEGIN	
		EXEC cd.SIBD.dbo.[usp_Get_SaldoAtual_Produto] @codigoEmpresa, @PROCOD, @pEstoque OUTPUT, @pLoja OUTPUT, @pCompras OUTPUT, @pTransito OUTPUT;
	END
	ELSE
	BEGIN
		SELECT @estoqueCd = -9999;
	END;

	-- Retorna o saldo disponivel do CD	
	SELECT
		@estoqueCd = @pEstoque 		
END
GO


