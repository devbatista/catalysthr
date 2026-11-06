# Be sure to restart your server when you modify this file.

# Filter sensitive parameters from logs, error reports and inspections
# (D-086, D-221, P-05-33). Use partial names: `:cpf` also filters `cpf_number`.
# `:login` is the sign-in field, which holds a CPF or an e-mail (RN-02-003).
Rails.application.config.filter_parameters += [
  :passw, :email, :login, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :cpf, :rg, :cnh, :pis, :nis, :ctps, :phone, :celular, :telefone, :birth, :nascimento,
  :salary, :salario, :bank, :pix, :agencia, :conta, :cid, :health, :saude, :address, :endereco,
  :credential, :nickname, :endpoint, :p256dh, /\Aauth\z/
]
