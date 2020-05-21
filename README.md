## Método API para Queries dinâmicas

Quando houver a necessidade de integração entre duas plataformas e houver muitas requisições de dados, não faz sentido criar um método GET para cada estrura requerida, a não ser que a mesma tenha alguma especificidade, sendo assim, para consultas genéricas, resolvi criar uma API dinânimca

### Pré-requisitos

Para execução desta API é necessário seguir alguns passos:
* [REST](https://tdn.totvs.com/pages/viewpage.action?pageId=185747842) - Configuração
* [INSOMNIA](https://insomnia.rest/) - Utilizei para testes de requisições o Insomnia, porém, há outros clientes, como por exemplo, o [POSTMAN](https://www.postman.com/) e também a o próprio [curl](https://curl.haxx.se/)

### Testando

Primeiro passo, é a compilação do arquivo [wsService.prw](wsService.prw) presente neste repositório

Após isso, simplesmente é realizar o consumo desta API da seguinte forma;

#### Requisição
![Requisição](https://i.ibb.co/1vQMw9g/request.png)

**curl:**

```shell
curl --request GET \
  --url http://localhost:8080/wsService/query \
  --header 'content-type: application/json' \
  --data '{
	"query": "SELECT A1_COD, A1_LOJA, A1_NOME FROM SA1000 WHERE D_E_L_E_T_ = '\'''\'' AND A1_NOME LIKE '\''CIRO%'\''"
}'
```

#### Resposta
![Resposta](https://i.ibb.co/YPS2kfr/response.png)

#### Observação
Para campos do tipo *MEMO* é necessário a realização do [CAST (Doc. Microsoft SQL)](https://docs.microsoft.com/pt-br/sql/t-sql/functions/cast-and-convert-transact-sql?view=sql-server-ver15) dentro do **body JSON**, exemplo:
```JSON
{
  "query": "SELECT CAST(CAST(CAMPO_MEMO AS VARBINARY(8000)) AS VARCHAR(8000)) FROM TABLE"
}
```

Então é isso! =)
