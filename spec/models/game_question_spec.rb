# (c) goodprogrammer.ru

require 'rails_helper'

# Тестовый сценарий для модели игрового вопроса, в идеале весь наш функционал
# (все методы) должны быть протестированы.
RSpec.describe GameQuestion, type: :model do
  # Задаем локальную переменную game_question, доступную во всех тестах этого
  # сценария: она будет создана на фабрике заново для каждого блока it,
  # где она вызывается.
  let(:game_question) do
    FactoryGirl.create(:game_question, a: 2, b: 1, c: 4, d: 3)
  end
  let(:game_question_bad) do
    FactoryGirl.create(:game_question_bad, a: 2, b: 2, c: 4, d: 3)
  end

  # Группа тестов на игровое состояние объекта вопроса
  context 'game status' do
    # Тест на правильную генерацию хэша с вариантами
    it 'correct .variants' do
      expect(game_question.variants).to eq(
        'a' => game_question.question.answer2,
        'b' => game_question.question.answer1,
        'c' => game_question.question.answer4,
        'd' => game_question.question.answer3
      )
    end

    it 'correct .answer_correct?' do
      # Именно под буквой b в тесте мы спрятали указатель на верный ответ
      expect(game_question.answer_correct?('b')).to be_truthy
    end

    it 'correct .correct_answer_key' do
      expect(game_question.correct_answer_key).to eq 'b'
    end

    it 'bad .correct_answer_key' do
      # отстутствие ключа правильного ответа
      expect(game_question_bad.correct_answer_key).to be_nil
    end

    # тест на наличие методов делегатов level и text
    it 'correct .level & .text delegates' do
      expect(game_question.text).to eq(game_question.question.text)
      expect(game_question.level).to eq(game_question.question.level)
    end

    it 'correct .help_hash' do
      # на фабрике у нас изначально хэш пустой
      expect(game_question.help_hash).to eq({})

      # добавляем пару ключей
      game_question.help_hash[:some_key1] = 'blabla1'
      game_question.help_hash['some_key2'] = 'blabla2'

      # сохраняем модель и ожидаем сохранения хорошего
      expect(game_question.save).to be_truthy

      # загрузим этот же вопрос из базы для чистоты эксперимента
      gq = GameQuestion.find(game_question.id)

      # проверяем новые значение хэша
      expect(gq.help_hash).to eq({some_key1: 'blabla1', 'some_key2' => 'blabla2'})
    end

  end

  # help_hash у нас имеет такой формат:
  # {
  #   fifty_fifty: ['a', 'b'], # При использовании подсказски остались варианты a и b
  #   audience_help: {'a' => 42, 'c' => 37 ...}, # Распределение голосов по вариантам a, b, c, d
  #   friend_call: 'Василий Петрович считает, что правильный ответ A'
  # }
  #

  # Группа тестов на помощь игроку
  context 'user helpers' do
    # проверяем работоспосбность "помощи зала"
    it 'correct audience_help' do
      # сначала убедимся, в подсказках пока нет нужного ключа
      expect(game_question.help_hash).not_to include(:audience_help)
      # вызовем подсказку
      game_question.add_audience_help

      # проверим создание подсказки
      expect(game_question.help_hash).to include(:audience_help)

      # мы не можем знать распределение, но может проверить хотя бы наличие нужных ключей
      ah = game_question.help_hash[:audience_help]
      expect(ah.keys).to contain_exactly('a', 'b', 'c', 'd')
    end


    # ---------------------------------------------

    # проверяем работу 50/50
    it 'correct fifty_fifty' do
      # сначала убедимся, в подсказках пока нет нужного ключа
      expect(game_question.help_hash).not_to include(:fifty_fifty)
      # вызовем подсказку
      game_question.add_fifty_fifty

      # проверим создание подсказки
      expect(game_question.help_hash).to include(:fifty_fifty)
      ff = game_question.help_hash[:fifty_fifty]

      expect(ff).to include('b') # должен остаться правильный вариант
      expect(ff.size).to eq 2 # всего должно остаться 2 варианта
    end

    # Дополнительно напишите тесты на случай использования одновременно 2 и более подсказок
    # После использования 50/50 например, аудитория и друг должны выбирать только
    # из 2 оставшихся вариантов и т. п.

    it 'friend_call' do
      expect(game_question.help_hash).not_to include(:friend_call)
      expect(game_question.send(:keys_to_use_in_help).size).to eq 4

      game_question.add_friend_call
      expect(game_question.help_hash).to include(:friend_call)
      frc = game_question.help_hash[:friend_call]
      expect(frc).to include('считает, что это вариант')
    end

    it 'fifty_fifty & friend_call' do
      expect(game_question.help_hash).not_to include(:fifty_fifty)
      expect(game_question.send(:keys_to_use_in_help).size).to eq 4

      game_question.add_fifty_fifty
      expect(game_question.help_hash).to include(:fifty_fifty)
      ff = game_question.help_hash[:fifty_fifty]
      expect(ff).to include('b')
      expect(ff.size).to eq 2

      expect(game_question.help_hash).not_to include(:friend_call)
      expect(game_question.send(:keys_to_use_in_help).size).to eq 2

      game_question.add_friend_call
      expect(game_question.help_hash).to include(:fifty_fifty)
      expect(game_question.help_hash).to include(:friend_call)
      frc = game_question.help_hash[:friend_call]
      expect(frc).to include('считает, что это вариант')
    end

    it 'all helpers' do
      expect(game_question.help_hash).not_to include(:fifty_fifty)
      expect(game_question.help_hash).not_to include(:friend_call)
      expect(game_question.help_hash).not_to include(:audience_help)
      expect(game_question.send(:keys_to_use_in_help).size).to eq 4

      game_question.add_fifty_fifty
      expect(game_question.help_hash).to include(:fifty_fifty)
      ff = game_question.help_hash[:fifty_fifty]
      expect(ff).to include('b')
      expect(ff.size).to eq 2

      expect(game_question.help_hash).not_to include(:friend_call)
      expect(game_question.help_hash).not_to include(:audience_help)
      expect(game_question.send(:keys_to_use_in_help).size).to eq 2

      game_question.add_friend_call
      expect(game_question.help_hash).to include(:fifty_fifty)
      expect(game_question.help_hash).to include(:friend_call)
      expect(game_question.help_hash).not_to include(:audience_help)
      frc = game_question.help_hash[:friend_call]
      expect(frc).to include('считает, что это вариант')

      expect(game_question.send(:keys_to_use_in_help).size).to eq 2

      game_question.add_audience_help
      expect(game_question.help_hash).to include(:fifty_fifty)
      expect(game_question.help_hash).to include(:friend_call)
      expect(game_question.help_hash).to include(:audience_help)
      ah = game_question.help_hash[:audience_help]
      expect(ah).to include('b')
    end


  end
end
